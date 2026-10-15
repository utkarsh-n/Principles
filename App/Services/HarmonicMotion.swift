import CoreMotion
import Foundation
import Observation
import UIKit

/// Gravity affects decorative reflections only. The service has no reference to
/// note, tuning, curriculum or audio state, so tilt cannot alter the experiment.
@MainActor @Observable
final class HarmonicMotion {
    private(set) var x = 0.0
    private(set) var y = 0.0
    private(set) var isActive = false
    private(set) var status = "Motion off"
    private(set) var sampleCount = 0
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Harmonic.MaterialMotion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var referenceX: Double?
    @ObservationIgnored private var referenceZ: Double?
    @ObservationIgnored private var lastTimestamp = -Double.infinity
    @ObservationIgnored private var backgroundObserver: NSObjectProtocol?

    init() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil,
            using: Self.backgroundHandler(for: self))
    }
    isolated deinit {
        manager.stopDeviceMotionUpdates()
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
    }

    func start() {
        guard !isActive else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        guard isAvailable else { status = "Motion unavailable — static material"; return }
        generation &+= 1
        let token = generation
        referenceX = nil; referenceZ = nil; lastTimestamp = -Double.infinity
        sampleCount = 0; x = 0; y = 0; isActive = true; status = "Material motion"
        manager.deviceMotionUpdateInterval = 1 / 30.0
        manager.startDeviceMotionUpdates(to: queue, withHandler: Self.handler(for: self, token: token))
    }

    func stop() {
        generation &+= 1
        manager.stopDeviceMotionUpdates()
        isActive = false; referenceX = nil; referenceZ = nil
        x = 0; y = 0; status = "Motion off"
    }

    private func receive(gravityX: Double?, gravityZ: Double?, timestamp: Double?, failed: Bool, token: UInt64) {
        guard isActive, token == generation else { return }
        if failed { stop(); status = "Motion unavailable — static material"; return }
        guard let gravityX, let gravityZ, let timestamp,
              gravityX.isFinite, gravityZ.isFinite, timestamp.isFinite, timestamp > lastTimestamp else { return }
        lastTimestamp = timestamp
        if referenceX == nil { referenceX = gravityX; referenceZ = gravityZ }
        let targetX = min(1, max(-1, (gravityX - (referenceX ?? gravityX)) * 1.7))
        let targetY = min(1, max(-1, (gravityZ - (referenceZ ?? gravityZ)) * 1.7))
        x += (targetX - x) * 0.18; y += (targetY - y) * 0.18
        sampleCount += 1
    }

    nonisolated private static func handler(for owner: HarmonicMotion, token: UInt64) -> @Sendable (CMDeviceMotion?, (any Error)?) -> Void {
        { [weak owner] update, error in
            // Framework objects remain on the acquisition queue. Only Sendable
            // primitive values cross to the UI actor; old run callbacks are rejected.
            let gravityX = update?.gravity.x
            let gravityZ = update?.gravity.z
            let timestamp = update?.timestamp
            let failed = error != nil
            Task { @MainActor [weak owner] in
                owner?.receive(gravityX: gravityX, gravityZ: gravityZ, timestamp: timestamp, failed: failed, token: token)
            }
        }
    }

    nonisolated private static func backgroundHandler(for owner: HarmonicMotion) -> @Sendable (Notification) -> Void {
        { [weak owner] _ in Task { @MainActor [weak owner] in owner?.stop() } }
    }
}
