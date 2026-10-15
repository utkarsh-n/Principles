import CoreHaptics
import Foundation
import Observation
import UIKit

/// Event cues encode accepted adjustment, selection and completion. They do not
/// reproduce a musical frequency or certify that the user felt a submitted cue.
@MainActor @Observable
final class HarmonicFeedback {
    var enabled = true { didSet { if !enabled { stop() } } }
    var strength = 0.65
    private(set) var emittedEventCount = 0
    private(set) var lastEvent = "none"
    private(set) var usedCoreHaptics = false
    private(set) var status = "Event feedback"

    @ObservationIgnored private var engine: CHHapticEngine?
    @ObservationIgnored private var players: [Cue: any CHHapticPatternPlayer] = [:]
    @ObservationIgnored private var engineID = UUID()
    @ObservationIgnored private var engineRunning = false
    @ObservationIgnored private var lastEmission = -Double.infinity
    @ObservationIgnored private let selectionGenerator = UISelectionFeedbackGenerator()
    @ObservationIgnored private let impactGenerator = UIImpactFeedbackGenerator(style: .soft)
    @ObservationIgnored private let successGenerator = UINotificationFeedbackGenerator()
    @ObservationIgnored private var backgroundObserver: NSObjectProtocol?
    @ObservationIgnored private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private enum Cue: String, CaseIterable {
        case fineUp, fineDown, semanticUp, semanticDown, selection, success, boundary
        var intensity: Float {
            switch self {
            case .fineUp: 0.45
            case .fineDown: 0.48
            case .semanticUp, .semanticDown: 0.7
            case .selection: 0.32
            case .success: 0.5
            case .boundary: 0.68
            }
        }
        var sharpness: Float {
            switch self {
            case .fineUp: 0.9
            case .fineDown: 0.2
            case .semanticUp: 0.6
            case .semanticDown: 0.08
            case .selection: 0.5
            case .success: 0.45
            case .boundary: 0.35
            }
        }
    }

    init() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil,
            using: Self.backgroundHandler(for: self))
    }
    isolated deinit {
        engine?.stop(completionHandler: nil)
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
    }

    func acceptedChange(upward: Bool = true, semantic: Bool = false) {
        emit(semantic ? (upward ? .semanticUp : .semanticDown) : (upward ? .fineUp : .fineDown), minimumGap: 0.045)
    }
    func selection() { emit(.selection, minimumGap: 0.045) }
    func success() { emit(.success, minimumGap: 0.1) }
    func boundary() { emit(.boundary, minimumGap: 0.1) }

    func stop() {
        players.values.forEach { try? $0.stop(atTime: CHHapticTimeImmediate) }
        engine?.stop(completionHandler: nil)
        engineRunning = false
        lastEmission = -Double.infinity
    }

    private func emit(_ cue: Cue, minimumGap: Double) {
        guard enabled, strength.isFinite, strength > 0,
              UIApplication.shared.applicationState == .active else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastEmission >= minimumGap else { return }
        lastEmission = now
        let amount = Float(min(1, max(0, strength)))
        usedCoreHaptics = false
        if supportsHaptics {
            do {
                try prepareEngine()
                if let player = players[cue] {
                    try player.sendParameters([
                        CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: amount, relativeTime: 0)
                    ], atTime: CHHapticTimeImmediate)
                    try player.start(atTime: CHHapticTimeImmediate)
                    usedCoreHaptics = true
                }
            } catch {
                engineRunning = false
                status = "System event feedback"
            }
        }
        if !usedCoreHaptics {
            switch cue {
            case .success: successGenerator.notificationOccurred(.success); successGenerator.prepare()
            case .selection, .fineUp, .fineDown: selectionGenerator.selectionChanged(); selectionGenerator.prepare()
            default: impactGenerator.impactOccurred(intensity: CGFloat(cue.intensity * amount)); impactGenerator.prepare()
            }
        }
        emittedEventCount += 1
        lastEvent = cue.rawValue
    }

    private func prepareEngine() throws {
        if engine == nil {
            let newEngine = try CHHapticEngine()
            let id = UUID()
            newEngine.playsHapticsOnly = true
            newEngine.isAutoShutdownEnabled = true
            newEngine.stoppedHandler = Self.stoppedHandler(for: self, id: id)
            newEngine.resetHandler = Self.resetHandler(for: self, id: id)
            engine = newEngine; engineID = id
        }
        guard let engine else { return }
        if !engineRunning { try engine.start(); engineRunning = true }
        if players.isEmpty {
            for cue in Cue.allCases {
                let first = CHHapticEvent(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: cue.intensity),
                    .init(parameterID: .hapticSharpness, value: cue.sharpness)
                ], relativeTime: 0)
                var events = [first]
                if cue == .success {
                    events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.65),
                        .init(parameterID: .hapticSharpness, value: 0.65)
                    ], relativeTime: 0.09))
                }
                players[cue] = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            }
        }
        status = "Event feedback"
    }

    nonisolated private static func backgroundHandler(for owner: HarmonicFeedback) -> @Sendable (Notification) -> Void {
        { [weak owner] _ in Task { @MainActor [weak owner] in owner?.stop() } }
    }
    nonisolated private static func stoppedHandler(for owner: HarmonicFeedback, id: UUID) -> @Sendable (CHHapticEngine.StoppedReason) -> Void {
        { [weak owner] _ in
            Task { @MainActor [weak owner] in
                guard let owner, owner.engineID == id else { return }
                owner.engineRunning = false
            }
        }
    }
    nonisolated private static func resetHandler(for owner: HarmonicFeedback, id: UUID) -> @Sendable () -> Void {
        { [weak owner] in
            Task { @MainActor [weak owner] in
                guard let owner, owner.engineID == id else { return }
                owner.players.removeAll(); owner.engineRunning = false
                // The next accepted action recreates players. No queued replay.
            }
        }
    }
}
