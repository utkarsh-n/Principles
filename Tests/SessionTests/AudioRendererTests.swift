import AVFoundation
import Foundation
import HarmonicCore
@testable import Harmonic
import XCTest

/// These tests exercise the production callback and inspect its actual Float PCM.
/// The reference calculations do not call MusicMath's waveform/FFT helpers.
final class AudioRendererTests: XCTestCase {
    private let sampleRate = 48_000.0

    func testKnownSineFrequencyAndIndependentRMS() throws {
        let harness = try Harness(configuration: ToneConfiguration(
            voices: [AudioVoice(frequency: 440, amplitudes: [1])], volume: 0.22))
        _ = try harness.render(12_000)
        let pcm = try harness.render(4_800)
        XCTAssertEqual(projectedAmplitude(pcm, frequency: 440), 0.22, accuracy: 0.00001)
        XCTAssertLessThan(projectedAmplitude(pcm, frequency: 880), 0.00001)
        XCTAssertEqual(rms(pcm), 0.22 / sqrt(2), accuracy: 0.00001)
        let lastBlock = try harness.render(1_024, blockSize: 1_024)
        XCTAssertEqual(harness.renderer.snapshot()?.rms ?? -1, rms(lastBlock), accuracy: 0.00000001)
        XCTAssertEqual(harness.renderer.snapshot()?.peak ?? -1, lastBlock.map { abs(Double($0)) }.max() ?? 0, accuracy: 0.00000001)
    }

    func testCombinedRecipeHasBoundedDigitalPeakAndFinitePCM() throws {
        let recipe = ToneConfiguration(voices: [
            AudioVoice(frequency: 110, amplitudes: Array(repeating: 1, count: 8)),
            AudioVoice(frequency: 220, amplitudes: Array(repeating: 1, count: 8), phase: 0.8),
            AudioVoice(frequency: 330, amplitudes: [1, 0.8, 0.6, 0.4]),
            AudioVoice(frequency: 440, amplitudes: [1, 1, 1, 1], phase: 1.2)
        ], volume: 0.5)
        let harness = try Harness(configuration: recipe)
        let pcm = try harness.render(48_000)
        XCTAssertTrue(pcm.allSatisfy { $0.isFinite })
        XCTAssertLessThanOrEqual(pcm.map { abs(Double($0)) }.max() ?? 1, 0.500001)
        XCTAssertGreaterThan(rms(pcm), 0.005)
    }

    func testSampleDeadlineEndsAuditionWithoutAUIClock() throws {
        let harness = try Harness(configuration: ToneConfiguration(
            voices: [AudioVoice(frequency: 440)]), duration: 0.1)
        let pcm = try harness.render(9_600)
        let state = try XCTUnwrap(harness.renderer.snapshot())
        XCTAssertFalse(state.isRendering)
        XCTAssertGreaterThanOrEqual(state.sampleTime, 4_800)
        XCTAssertLessThanOrEqual(state.sampleTime, 4_800 + 577)
        XCTAssertEqual(state.status, "Audition complete")
        XCTAssertTrue(pcm[5_400...].allSatisfy { $0 == 0 })
        let sampleTime = state.sampleTime
        XCTAssertTrue(try harness.render(512).allSatisfy { $0 == 0 })
        XCTAssertEqual(harness.renderer.snapshot()?.sampleTime, sampleTime)
    }

    func testRetuningKeepsPhaseAndAvoidsAnInstantaneousDiscontinuity() throws {
        let harness = try Harness(configuration: ToneConfiguration(
            voices: [AudioVoice(frequency: 440)], volume: 0.22))
        let prefixCount = 10_001
        let prefix = try harness.render(prefixCount)
        let retainedPhaseReference = 0.22 * sin(2 * Double.pi * 440 * Double(prefixCount) / sampleRate)
        harness.update(ToneConfiguration(voices: [AudioVoice(frequency: 660, phase: 1.7)], volume: 0.35))
        let transition = try harness.render(512)
        XCTAssertEqual(Double(transition[0]), retainedPhaseReference, accuracy: 0.004)
        let joined = [try XCTUnwrap(prefix.last)] + transition
        let largestJump = zip(joined, joined.dropFirst()).map { abs(Double($1) - Double($0)) }.max() ?? 0
        XCTAssertLessThan(largestJump, 0.055)
        _ = try harness.render(12_000)
        let settled = try harness.render(4_800)
        XCTAssertEqual(projectedAmplitude(settled, frequency: 660), 0.35, accuracy: 0.00002)
        XCTAssertEqual(harness.renderer.snapshot()?.appliedRevision, 2)
    }

    func testSixteenthSequencerRestsAndPitchAgreeWithActualPCM() throws {
        // At 120 BPM a sixteenth lasts 125 ms = 6,000 frames. The two
        // pitched slots are A4 and A5, separated by a complete silent slot.
        let harness = try Harness(configuration: ToneConfiguration(
            voices: [AudioVoice(frequency: 440)], volume: 0.22, bpm: 120,
            stepNotes: [69, -1, 81, -1], isSequenced: true))
        let pcm = try harness.render(24_000)
        XCTAssertGreaterThan(rms(Array(pcm[2_000..<5_000])), 0.1)
        XCTAssertTrue(pcm[6_002..<12_000].allSatisfy { abs($0) < 0.0000001 })
        XCTAssertTrue(pcm[18_002..<24_000].allSatisfy { abs($0) < 0.0000001 })
        let octave = Array(pcm[16_000..<17_600])
        XCTAssertGreaterThan(projectedAmplitude(octave, frequency: 880), 0.20)
        XCTAssertLessThan(projectedAmplitude(octave, frequency: 440), 0.012)
        // The start/finish tapers are tied to sample-clock slot boundaries.
        XCTAssertLessThan(abs(Double(pcm[5_999])), 0.001)
        XCTAssertLessThan(abs(Double(pcm[17_999])), 0.001)
    }

    func testEditingASequenceDuringAHeldSlotKeepsItsMIDIPitch() throws {
        var recipe = ToneConfiguration(voices: [AudioVoice(frequency: 110)], volume: 0.22,
            bpm: 60, stepNotes: [81], isSequenced: true)
        let harness = try Harness(configuration: recipe)
        _ = try harness.render(5_000)
        recipe.volume = 0.25
        harness.update(recipe)
        _ = try harness.render(4_000)
        let pcm = try harness.render(1_920)
        XCTAssertGreaterThan(projectedAmplitude(pcm, frequency: 880), 0.23)
        XCTAssertLessThan(projectedAmplitude(pcm, frequency: 110), 0.01)
    }

    func testProductionCompositionRetriggersDecayOnLaterLoops() throws {
        let recipe = LabModel.audio(LabState(kind: .composition))
        XCTAssertTrue(recipe.isSequenced)
        XCTAssertGreaterThan(recipe.voices.first?.decay ?? 0, 0)
        let harness = try Harness(configuration: recipe)
        let cycleFrames = Int((16 * 15 / recipe.bpm * sampleRate).rounded())
        let laterOnset = 2 * cycleFrames
        let pcm = try harness.render(laterOnset + 6_000)
        let first = rms(Array(pcm[1_920..<5_760]))
        let later = rms(Array(pcm[(laterOnset + 1_920)..<(laterOnset + 5_760)]))
        XCTAssertGreaterThan(first, 0.02)
        // The same sounding slot five seconds later remains a fresh note,
        // rather than the near-silent tail of the entire audition's decay.
        XCTAssertEqual(later / first, 1, accuracy: 0.03)
    }

    func testHeldSlotRecipeEditDoesNotRetriggerItsDecay() throws {
        let recipe = LabModel.audio(LabState(kind: .composition))
        let control = try Harness(configuration: recipe)
        let edited = try Harness(configuration: recipe)
        _ = try control.render(3_000)
        _ = try edited.render(3_000)
        edited.update(recipe)
        let reference = try control.render(1_000)
        let actual = try edited.render(1_000)
        for index in actual.indices {
            XCTAssertEqual(actual[index], reference[index], accuracy: 0.0000001)
        }
    }

    func testExactThreeAgainstTwoOnsetsAndCoincidences() throws {
        // A four-quarter cycle at 120 BPM is two seconds. The thirds
        // are not representable on the app's sixteen-step composition grid.
        let harness = try Harness(configuration: ToneConfiguration(volume: 0.3,
            bpm: 120, rhythmCounts: [3, 2]))
        let pcm = try harness.render(103_200)
        let expected = [0, 32_000, 48_000, 64_000, 96_000]
        for frame in expected {
            let onset = try firstAudibleFrame(pcm, around: frame)
            XCTAssertGreaterThanOrEqual(onset, frame)
            XCTAssertLessThanOrEqual(onset, frame + 2)
        }
        let third = Array(pcm[32_240..<33_920])
        let half = Array(pcm[48_240..<49_920])
        XCTAssertGreaterThan(projectedAmplitude(third, frequency: 660), 5 * projectedAmplitude(third, frequency: 330))
        XCTAssertGreaterThan(projectedAmplitude(half, frequency: 330), 5 * projectedAmplitude(half, frequency: 660))
        let coincidence = Array(pcm[96_240..<97_920])
        XCTAssertGreaterThan(projectedAmplitude(coincidence, frequency: 660), 0.015)
        XCTAssertGreaterThan(projectedAmplitude(coincidence, frequency: 330), 0.015)
        // Empty stretches exclude extra quantized-grid pulses.
        XCTAssertTrue(pcm[36_000..<47_500].allSatisfy { $0 == 0 })
        XCTAssertTrue(pcm[68_000..<95_500].allSatisfy { $0 == 0 })
    }

    func testRhythmPhaseOffsetsOnlyTheSecondTrain() throws {
        let harness = try Harness(configuration: ToneConfiguration(volume: 0.3,
            bpm: 120, rhythmCounts: [3, 2], rhythmPhase: .pi / 2))
        let pcm = try harness.render(78_000)
        for frame in [0, 24_000, 32_000, 64_000, 72_000] {
            let onset = try firstAudibleFrame(pcm, around: frame)
            XCTAssertGreaterThanOrEqual(onset, frame)
            XCTAssertLessThanOrEqual(onset, frame + 2)
        }
        XCTAssertTrue(pcm[48_000..<49_000].allSatisfy { $0 == 0 })
        let initial = Array(pcm[240..<1_920])
        XCTAssertGreaterThan(projectedAmplitude(initial, frequency: 660), 5 * projectedAmplitude(initial, frequency: 330))
        let shifted = Array(pcm[24_240..<25_920])
        XCTAssertGreaterThan(projectedAmplitude(shifted, frequency: 330), 5 * projectedAmplitude(shifted, frequency: 660))
    }

    func testHighPartialsAreOmittedRatherThanAliasedIntoAudibleBand() throws {
        let harness = try Harness(configuration: ToneConfiguration(
            voices: [AudioVoice(frequency: 7_000, amplitudes: [1, 1, 1, 1])], volume: 0.3))
        _ = try harness.render(12_000)
        let pcm = try harness.render(4_800)
        XCTAssertEqual(projectedAmplitude(pcm, frequency: 7_000), 0.1, accuracy: 0.00001)
        XCTAssertEqual(projectedAmplitude(pcm, frequency: 14_000), 0.1, accuracy: 0.00001)
        XCTAssertEqual(projectedAmplitude(pcm, frequency: 21_000), 0.1, accuracy: 0.00001)
        // An unguarded 28 kHz partial would fold to 20 kHz at Fs=48 kHz.
        XCTAssertLessThan(projectedAmplitude(pcm, frequency: 20_000), 0.00001)
        let rejected = try Harness(configuration: ToneConfiguration(
            voices: [AudioVoice(frequency: 22_000)], volume: 0.3))
        XCTAssertTrue(try rejected.render(1_000).allSatisfy { $0 == 0 })
    }

    func testLiveEditFadesAnOmittedPartialAtItsPreviousLegalFrequency() throws {
        // The dominant third partial starts at 21 kHz. Retuning its
        // fundamental to 9 kHz omits the now-27 kHz third. Its release must
        // agree with a legal 21 kHz fade, rather than sweeping through aliases.
        let start = ToneConfiguration(voices: [AudioVoice(frequency: 7_000,
            amplitudes: [0.001, 0, 1])], volume: 0.3)
        let retuned = try Harness(configuration: start)
        let fadeControl = try Harness(configuration: start)
        _ = try retuned.render(10_000)
        _ = try fadeControl.render(10_000)
        retuned.update(ToneConfiguration(voices: [AudioVoice(frequency: 9_000,
            amplitudes: [0.001, 0, 1])], volume: 0.3))
        fadeControl.update(ToneConfiguration(voices: [AudioVoice(frequency: 7_000,
            amplitudes: [0.001, 0, 0])], volume: 0.3))
        let actual = try retuned.render(2_400)
        let reference = try fadeControl.render(2_400)
        var difference = 0.0
        for index in actual.indices { difference = max(difference, abs(Double(actual[index]) - Double(reference[index]))) }
        // Only the tiny fundamentals differ: their combined peak is <0.0006.
        XCTAssertLessThan(difference, 0.0007)
    }

    func testRevisionsAcknowledgeOnlyRenderedConfigurationsAndCoalesceEdits() throws {
        let harness = try Harness(configuration: ToneConfiguration(voices: [AudioVoice(frequency: 220)]))
        _ = try harness.render(64)
        XCTAssertEqual(harness.renderer.snapshot()?.appliedRevision, 1)
        harness.update(ToneConfiguration(voices: [AudioVoice(frequency: 330)]))
        XCTAssertEqual(harness.revision, 2)
        XCTAssertEqual(harness.renderer.snapshot()?.appliedRevision, 1)
        harness.update(ToneConfiguration(voices: [AudioVoice(frequency: 440)]))
        XCTAssertEqual(harness.revision, 3)
        _ = try harness.render(64)
        XCTAssertEqual(harness.renderer.snapshot()?.appliedRevision, 3)
        harness.stop()
        _ = try harness.render(1_024)
        let state = try XCTUnwrap(harness.renderer.snapshot())
        XCTAssertEqual(state.appliedRevision, 4)
        XCTAssertFalse(state.isRendering)
        XCTAssertLessThanOrEqual(state.appliedRevision, harness.revision)
    }

    private func rms(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        var sum = 0.0
        for sample in samples { sum += Double(sample) * Double(sample) }
        return sqrt(sum / Double(samples.count))
    }

    private func projectedAmplitude(_ samples: [Float], frequency: Double) -> Double {
        guard !samples.isEmpty else { return 0 }
        var sine = 0.0, cosine = 0.0
        for (index, sample) in samples.enumerated() {
            let angle = 2 * Double.pi * frequency * Double(index) / sampleRate
            sine += Double(sample) * sin(angle)
            cosine += Double(sample) * cos(angle)
        }
        return 2 * hypot(sine, cosine) / Double(samples.count)
    }

    private func firstAudibleFrame(_ samples: [Float], around expected: Int) throws -> Int {
        let start = max(0, expected - 200), end = min(samples.count, expected + 200)
        return try XCTUnwrap((start..<end).first { abs(samples[$0]) > 0.000001 }, "No PCM onset around frame \(expected)")
    }

    private final class Harness {
        let renderer: RealtimeToneRenderer
        private let format: AVAudioFormat
        private var configuration: ToneConfiguration
        private let duration: Double
        private var hostFrames: UInt64 = 0
        private(set) var revision: UInt64 = 1

        init(configuration: ToneConfiguration, duration: Double = 12) throws {
            let rate = 48_000.0
            format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
            renderer = RealtimeToneRenderer(sampleRate: rate)
            self.configuration = configuration.sanitized(sampleRate: rate)
            self.duration = duration
            renderer.publish(configuration: self.configuration, revision: 1, playSerial: 1, wanted: true, duration: duration)
        }
        func update(_ configuration: ToneConfiguration) {
            self.configuration = configuration.sanitized(sampleRate: renderer.sampleRate)
            revision += 1
            renderer.publish(configuration: self.configuration, revision: revision, playSerial: 1, wanted: true, duration: duration)
        }
        func stop() {
            revision += 1
            renderer.publish(configuration: configuration, revision: revision, playSerial: 1, wanted: false, duration: duration)
        }
        func render(_ count: Int, blockSize: Int = 256) throws -> [Float] {
            var result: [Float] = []
            result.reserveCapacity(count)
            while result.count < count {
                let frames = min(blockSize, count - result.count)
                let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
                buffer.frameLength = AVAudioFrameCount(frames)
                var silence = ObjCBool(false)
                var timestamp = AudioTimeStamp()
                timestamp.mHostTime = AVAudioTime.hostTime(forSeconds: 100 + Double(hostFrames) / renderer.sampleRate)
                let resultCode = renderer.render(isSilence: &silence, timestamp: &timestamp,
                    frameCount: AVAudioFrameCount(frames), audioBufferList: buffer.mutableAudioBufferList)
                XCTAssertEqual(resultCode, noErr)
                let channel = try XCTUnwrap(buffer.floatChannelData?[0])
                result.append(contentsOf: UnsafeBufferPointer(start: channel, count: frames))
                hostFrames += UInt64(frames)
            }
            return result
        }
    }
}
