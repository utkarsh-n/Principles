import HarmonicCore
@testable import Harmonic
import XCTest

/// App-hosted tests of the actual production AVAudioEngine service. A silent
/// recipe exercises the real render callback without generating audible test tones.
@MainActor
final class AudioEngineIntentTests: XCTestCase {
    func testImmediateEditAndStopUseAcceptedIntentBeforeFirstPoll() throws {
        let audio = try activeEngine()
        defer { audio.suspend() }
        let start = audio.play(configuration: silentTone(220), duration: 1)
        XCTAssertTrue(audio.isPlaybackRequested, audio.status)
        XCTAssertTrue(audio.isStarting)
        XCTAssertFalse(audio.isPlaying)
        let edit = audio.update(configuration: silentTone(660))
        XCTAssertGreaterThan(edit, start)
        XCTAssertEqual(audio.requestedRevision, edit)
        XCTAssertTrue(audio.isPlaybackRequested)
        XCTAssertTrue(audio.isStarting)
        // A second transport tap takes this branch immediately; it must not
        // restart Play just because acknowledged output is still false.
        if audio.isPlaybackRequested { audio.stop() }
        XCTAssertFalse(audio.isPlaybackRequested)
        XCTAssertFalse(audio.isStarting)
        XCTAssertGreaterThan(audio.requestedRevision, edit)
    }

    func testImmediateEditReachesActualRendererAcknowledgement() async throws {
        let audio = try activeEngine()
        defer { audio.suspend() }
        _ = audio.play(configuration: silentTone(220), duration: 1)
        let editedRevision = audio.update(configuration: silentTone(660))
        XCTAssertTrue(audio.isPlaybackRequested, audio.status)
        XCTAssertTrue(audio.isStarting)
        try await waitUntil { audio.appliedRevision == editedRevision && audio.isPlaying }
        XCTAssertFalse(audio.isStarting)
        XCTAssertTrue(audio.isPlaybackRequested)
        XCTAssertGreaterThan(audio.sampleTime, 0)
        XCTAssertEqual(audio.telemetry.peak, 0)
    }

    func testActualSampleDeadlineClearsRequestedIntent() async throws {
        let audio = try activeEngine()
        defer { audio.suspend() }
        let revision = audio.play(configuration: silentTone(440), duration: 0.1)
        XCTAssertTrue(audio.isPlaybackRequested, audio.status)
        try await waitUntil { !audio.isPlaybackRequested }
        XCTAssertFalse(audio.isStarting)
        XCTAssertFalse(audio.isPlaying)
        XCTAssertEqual(audio.appliedRevision, revision)
        XCTAssertGreaterThanOrEqual(audio.sampleTime, UInt64((audio.sampleRate * 0.1).rounded()))
        XCTAssertEqual(audio.status, "Audition complete")
    }

    func testSuspensionClearsStartingIntentAndRejectsQueuedPolling() async throws {
        let audio = try activeEngine()
        _ = audio.play(configuration: silentTone(330), duration: 1)
        XCTAssertTrue(audio.isPlaybackRequested, audio.status)
        audio.suspend()
        XCTAssertFalse(audio.isPlaybackRequested)
        XCTAssertFalse(audio.isStarting)
        XCTAssertFalse(audio.isPlaying)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(audio.isPlaybackRequested)
        XCTAssertFalse(audio.isPlaying)
        XCTAssertEqual(audio.status, "Audition paused. Tap Audition to play again.")
    }

    private func activeEngine() throws -> HarmonicAudioEngine {
        let audio = HarmonicAudioEngine()
        guard audio.canPlay else {
            throw XCTSkip("Requires the native app test host to be active; background state is not a startup-intent failure.")
        }
        return audio
    }

    private func silentTone(_ frequency: Double) -> ToneConfiguration {
        ToneConfiguration(voices: [AudioVoice(frequency: frequency)], volume: 0)
    }

    private func waitUntil(_ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Production audio engine did not reach the expected state within two seconds.")
    }
}
