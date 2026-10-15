import AVFoundation
import Foundation
import HarmonicCore
import Observation
import UIKit

/// Foreground auditions only. Acknowledgement means samples reached our render
/// callback; accessory, speaker and acoustic latency are not measured here.
@MainActor @Observable
final class HarmonicAudioEngine {
    private(set) var telemetry = HarmonicAudioTelemetry()
    private(set) var outputRouteLabel = "Audio output"
    private(set) var status = "Ready" { didSet { telemetry.status = status } }
    /// Transport follows the accepted request immediately, including the interval
    /// before our first telemetry poll. This is separate from rendered output.
    private(set) var isPlaybackRequested = false
    var isStarting: Bool {
        isPlaybackRequested && (telemetry.appliedRevision < playStartRevision || !telemetry.isRendering)
    }
    var isPlaying: Bool { telemetry.isRendering && audioEngine?.isRunning == true }
    var canPlay: Bool { UIApplication.shared.applicationState == .active }
    var requestedRevision: UInt64 { telemetry.requestedRevision }
    var appliedRevision: UInt64 { telemetry.appliedRevision }
    var sampleTime: UInt64 { telemetry.sampleTime }
    var sampleRate: Double { telemetry.sampleRate }
    var peak: Double { telemetry.peak }

    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var sourceNode: AVAudioSourceNode?
    @ObservationIgnored private var renderer: RealtimeToneRenderer?
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var configuration = ToneConfiguration(voices: [])
    @ObservationIgnored private var revision: UInt64 = 0
    @ObservationIgnored private var playSerial: UInt64 = 0
    private var playStartRevision: UInt64 = 0
    @ObservationIgnored private var duration = 12.0
    @ObservationIgnored private var ownsSession = false
    @ObservationIgnored private var generation: UInt64 = 0

    init() {
        outputRouteLabel = Self.routeLabel()
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil,
                               using: Self.interruptionHandler(for: self)),
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil,
                               using: Self.routeHandler(for: self)),
            center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil,
                               using: Self.resetHandler(for: self)),
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil,
                               using: Self.backgroundHandler(for: self)),
            center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: nil,
                               using: Self.configurationHandler(for: self)),
        ]
    }

    isolated deinit {
        pollingTask?.cancel()
        audioEngine?.stop()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        if ownsSession { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }

    @discardableResult
    func play(configuration: ToneConfiguration, duration: Double = 12) -> UInt64 {
        guard canPlay else {
            shutDownAudio()
            status = "Open the app to audition."
            return revision
        }
        do {
            if audioEngine?.isRunning != true { try prepareAudio() }
            guard let renderer else { throw AudioError.missingRenderer }
            self.configuration = configuration.sanitized(sampleRate: renderer.sampleRate)
            self.duration = duration.isFinite ? min(30, max(0.1, duration)) : 12
            revision &+= 1; playSerial &+= 1
            playStartRevision = revision
            isPlaybackRequested = true
            renderer.publish(configuration: self.configuration, revision: revision, playSerial: playSerial,
                             wanted: true, duration: self.duration)
            telemetry.requestedRevision = revision
            status = "Starting audition"
            startPolling()
        } catch {
            shutDownAudio()
            status = "Sound is unavailable. Try Audition again."
            telemetry.status = status
        }
        return revision
    }

    @discardableResult
    func update(configuration: ToneConfiguration) -> UInt64 {
        let rate = renderer?.sampleRate ?? telemetry.sampleRate
        self.configuration = configuration.sanitized(sampleRate: rate)
        revision &+= 1
        telemetry.requestedRevision = revision
        if let renderer, audioEngine?.isRunning == true {
            renderer.publish(configuration: self.configuration, revision: revision, playSerial: playSerial,
                             wanted: isPlaybackRequested, duration: duration)
            if isPlaybackRequested { status = isStarting ? "Starting audition" : "Applying settings" }
        } else {
            shutDownAudio()
            status = "Ready"
        }
        return revision
    }

    /// User Stop gets a short render-owned gain ramp. Suspension immediately tears
    /// down the graph so backgrounding cannot restart an audition from queued work.
    func stop() {
        isPlaybackRequested = false
        guard let renderer, audioEngine?.isRunning == true else { shutDownAudio(); status = "Stopped"; return }
        revision &+= 1; telemetry.requestedRevision = revision
        renderer.publish(configuration: configuration, revision: revision, playSerial: playSerial,
                         wanted: false, duration: duration)
        status = "Stopping"
        startPolling()
    }

    func suspend() {
        isPlaybackRequested = false
        shutDownAudio()
        status = "Audition paused. Tap Audition to play again."
        telemetry.status = status
    }

    private func prepareAudio() throws {
        shutDownAudio()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
        try session.setPreferredSampleRate(48_000)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        ownsSession = true
        let rate = session.sampleRate.isFinite && session.sampleRate > 0 ? session.sampleRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { throw AudioError.format }
        let engine = AVAudioEngine()
        let render = RealtimeToneRenderer(sampleRate: rate)
        let source = Self.makeSourceNode(format: format, renderer: render)
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.prepare()
        audioEngine = engine; sourceNode = source; renderer = render
        telemetry.sampleRate = rate
        try engine.start()
        outputRouteLabel = Self.routeLabel()
    }

    /// AVAudioSourceNode invokes this block on its audio thread. Creating it in a
    /// nonisolated context prevents inheritance of the service's MainActor.
    nonisolated private static func makeSourceNode(format: AVAudioFormat,
                                                   renderer: RealtimeToneRenderer) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { isSilence, timestamp, count, buffers in
            renderer.render(isSilence: isSilence, timestamp: timestamp,
                            frameCount: count, audioBufferList: buffers)
        }
    }

    private func startPolling() {
        pollingTask?.cancel()
        let token = generation
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, token == self.generation, let render = self.renderer else { return }
                if var next = render.snapshot() {
                    next.requestedRevision = self.revision
                    self.telemetry = next
                    self.outputRouteLabel = Self.routeLabel()
                    // A finished current audition clears transport even while a
                    // later edit is waiting. A previous audition's stale snapshot
                    // cannot clear the intent of a newly accepted Play request.
                    if self.playStartRevision != 0, next.appliedRevision >= self.playStartRevision,
                       !next.isRendering {
                        self.shutDownAudio()
                        self.status = next.status
                        return
                    }
                    if next.appliedRevision == self.revision {
                        self.status = next.status
                    }
                }
                do { try await Task.sleep(for: .milliseconds(50)) }
                catch { return }
            }
        }
    }

    private func shutDownAudio() {
        isPlaybackRequested = false
        playStartRevision = 0
        generation &+= 1
        pollingTask?.cancel(); pollingTask = nil
        audioEngine?.stop()
        sourceNode = nil; audioEngine = nil; renderer = nil
        telemetry.isRendering = false; telemetry.peak = 0; telemetry.rms = 0
        if ownsSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsSession = false
        }
    }

    private enum AudioError: Error { case format, missingRenderer }
    private static func routeLabel() -> String {
        let names = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portName)
        return names.isEmpty ? "No audio output" : names.joined(separator: ", ")
    }

    #if DEBUG
    /// Render evidence only. It does not certify audible output or felt feedback.
    var debugSummary: String {
        "requested=\(requestedRevision); applied=\(appliedRevision); intent=\(isPlaybackRequested); starting=\(isStarting); rendering=\(telemetry.isRendering); " +
        "samples=\(sampleTime); rate=\(sampleRate); peak=\(peak); rms=\(telemetry.rms); " +
        "blocks=\(telemetry.renderedBlocks); nonzero=\(telemetry.nonzeroSamples); route=\(outputRouteLabel); status=\(status)"
    }
    #endif

    nonisolated private static func interruptionHandler(for owner: HarmonicAudioEngine) -> @Sendable (Notification) -> Void {
        { [weak owner] notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak owner] in owner?.suspend() }
        }
    }
    nonisolated private static func routeHandler(for owner: HarmonicAudioEngine) -> @Sendable (Notification) -> Void {
        { [weak owner] notification in
            guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue ||
                  raw == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue ||
                  raw == AVAudioSession.RouteChangeReason.routeConfigurationChange.rawValue else { return }
            Task { @MainActor [weak owner] in
                owner?.suspend()
                owner?.outputRouteLabel = routeLabel()
                owner?.status = "Audio output changed. Tap Audition to play again."
            }
        }
    }
    nonisolated private static func resetHandler(for owner: HarmonicAudioEngine) -> @Sendable (Notification) -> Void {
        { [weak owner] _ in Task { @MainActor [weak owner] in owner?.suspend() } }
    }
    nonisolated private static func backgroundHandler(for owner: HarmonicAudioEngine) -> @Sendable (Notification) -> Void {
        { [weak owner] _ in Task { @MainActor [weak owner] in owner?.suspend() } }
    }
    nonisolated private static func configurationHandler(for owner: HarmonicAudioEngine) -> @Sendable (Notification) -> Void {
        { [weak owner] _ in
            Task { @MainActor [weak owner] in
                guard let owner, let engine = owner.audioEngine, !engine.isRunning else { return }
                owner.suspend()
                owner.status = "Audio engine changed. Tap Audition to play again."
            }
        }
    }
}
