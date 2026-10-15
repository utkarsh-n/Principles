import XCTest
@testable import HarmonicCore

final class ModelTests: XCTestCase {
    func testConcertPitchOctaveCentsAndInverse() {
        XCTAssertEqual(MusicMath.frequency(midi: 69), 440, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.frequency(midi: 60), 261.6255653005986, accuracy: 1e-10)
        for midi in 21...108 {
            let f = MusicMath.frequency(midi: midi)
            XCTAssertEqual(MusicMath.frequency(midi: midi + 12), f * 2, accuracy: 1e-8)
            XCTAssertEqual(MusicMath.midi(frequency: f), Double(midi), accuracy: 1e-10)
        }
        XCTAssertEqual(MusicMath.cents(ratio: 1.5), 701.9550008653874, accuracy: 1e-9)
        XCTAssertEqual(MusicMath.cents(ratio: 1.25), 386.3137138648348, accuracy: 1e-9)
        for cents in stride(from: -1200.0, through: 1200, by: 37) {
            XCTAssertEqual(MusicMath.cents(ratio: MusicMath.ratio(cents: cents)), cents, accuracy: 1e-9)
        }
        XCTAssertNotEqual(MusicMath.equalRatio(semitones: 4), MusicMath.simpleRatio(semitones: 4))
        XCTAssertEqual(MusicMath.simpleRatio(semitones: -7), 2.0/3, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.noteName(-1), "B-2")
    }

    func testIdealStringSquareRootAndInverseLengthLawsAndNodes() {
        let f = MusicMath.stringFrequency(length: 0.5, tension: 100, density: 0.01)
        XCTAssertEqual(f, 100, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.stringFrequency(length: 0.25, tension: 100, density: 0.01), 2 * f, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.stringFrequency(length: 0.5, tension: 400, density: 0.01), 2 * f, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.stringFrequency(length: 0.5, tension: 100, density: 0.04), f / 2, accuracy: 1e-12)
        for mode in 1...8 {
            XCTAssertEqual(MusicMath.stringFrequency(length: 0.5, tension: 100, density: 0.01, harmonic: mode), Double(mode) * f, accuracy: 1e-12)
            for node in 0...mode {
                XCTAssertEqual(MusicMath.stringShape(position: Double(node) / Double(mode) * 0.5, length: 0.5, harmonic: mode), 0, accuracy: 1e-12)
            }
        }
        XCTAssertEqual(MusicMath.stringFrequency(length: 0, tension: 100, density: 1), 0)
    }

    func testBeatIdentityAndEnvelopeMaxima() {
        XCTAssertEqual(MusicMath.beatFrequency(440, 443), 3)
        for index in 0...100 {
            let t = Double(index) / 137
            let summed = 0.5 * (sin(2 * .pi * 440 * t) + sin(2 * .pi * 443 * t))
            let identity = sin(2 * .pi * 441.5 * t) * cos(.pi * 3 * t)
            XCTAssertEqual(summed, identity, accuracy: 1e-10)
        }
        XCTAssertEqual(MusicMath.beatEnvelope(difference: 3, time: 1.0/3), 1, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.beatEnvelope(difference: 3, time: 1.0/6), 0, accuracy: 1e-12)
    }

    func testAdditiveSpectrumOrthogonalityAndBound() {
        let weights = [1.0, 0.5, 0.25, 0.125]
        let count = 4096
        let samples = (0..<count).map { MusicMath.additiveSample(time: Double($0) / Double(count), frequency: 1, amplitudes: weights) }
        let sum = weights.reduce(0, +)
        for n in 1...6 {
            let projection = 2 / Double(count) * samples.enumerated().reduce(0.0) {
                $0 + $1.element * sin(2 * .pi * Double(n * $1.offset) / Double(count))
            }
            XCTAssertEqual(projection, n <= 4 ? weights[n - 1] / sum : 0, accuracy: 1e-10)
        }
        XCTAssertTrue(samples.allSatisfy { abs($0) <= 1 })
        XCTAssertEqual(MusicMath.additiveSample(time: 0.25, frequency: 1, amplitudes: [0.2]), 0.2, accuracy: 1e-12)
    }

    func testDecayHalfLifeAndAmplitudeVersusEnergy() {
        let tau = 0.7
        XCTAssertEqual(MusicMath.envelope(time: tau, decay: tau), exp(-1), accuracy: 1e-12)
        XCTAssertEqual(MusicMath.envelope(time: MusicMath.halfLife(decay: tau), decay: tau), 0.5, accuracy: 1e-12)
        let amplitude = MusicMath.envelope(time: tau * log(2) / 2, decay: tau)
        XCTAssertEqual(amplitude * amplitude, 0.5, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.envelope(time: 0, decay: 0), 0)
    }

    func testRCResponseAndDoublingResistance() {
        let fc = MusicMath.rcCutoff(resistance: 1000, capacitance: 1e-6)
        XCTAssertEqual(fc, 159.15494309189535, accuracy: 1e-9)
        XCTAssertEqual(MusicMath.lowPassGain(frequency: 0, cutoff: fc), 1, accuracy: 1e-12)
        let gain = MusicMath.lowPassGain(frequency: fc, cutoff: fc)
        XCTAssertEqual(gain, 1 / sqrt(2), accuracy: 1e-12)
        XCTAssertEqual(20 * log10(gain), -3.010299956639812, accuracy: 1e-10)
        XCTAssertEqual(MusicMath.lowPassPhase(frequency: fc, cutoff: fc), -.pi / 4, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.rcCutoff(resistance: 2000, capacitance: 1e-6), fc / 2, accuracy: 1e-12)
        XCTAssertLessThan(MusicMath.lowPassGain(frequency: 10 * fc, cutoff: fc), MusicMath.lowPassGain(frequency: fc, cutoff: fc))
        var state = LabState(kind: .filter)
        state.set(id: "frequency", value: fc)
        let config = LabModel.audio(state).sanitized(sampleRate: 48000)
        XCTAssertEqual(config.voices[0].amplitudes[0], gain, accuracy: 1e-9, "Normalization must preserve the low-pass attenuation")
        XCTAssertEqual(config.voices[0].phase, 7 * .pi / 4, accuracy: 1e-9)
    }

    func testResonancePeakDiffersFromNaturalAndDisappearsWithHeavyDamping() {
        let peak = MusicMath.resonancePeak(natural: 220, damping: 0.2)
        XCTAssertLessThan(peak, 220)
        let peakGain = MusicMath.resonanceGain(frequency: peak, natural: 220, damping: 0.2)
        XCTAssertGreaterThan(peakGain, MusicMath.resonanceGain(frequency: 220, natural: 220, damping: 0.2))
        XCTAssertEqual(MusicMath.resonanceGain(frequency: 220, natural: 220, damping: 0.2), 2.5, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.resonancePhase(frequency: 220, natural: 220, damping: 0.2), -.pi / 2, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.resonancePeak(natural: 220, damping: 0.8), 0)
        XCTAssertEqual(MusicMath.resonanceGain(frequency: 0, natural: 220, damping: 0.8), 1)
    }

    func testAliasingFoldsAndSampleIdentity() {
        XCTAssertEqual(MusicMath.aliasFrequency(frequency: 1000, sampleRate: 1200), 200, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.aliasFrequency(frequency: 3400, sampleRate: 1200), 200, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.aliasFrequency(frequency: 600, sampleRate: 1200), 600)
        for k in 0...20 {
            let original = sin(2 * .pi * 1000 * Double(k) / 1200)
            let aliased = -sin(2 * .pi * 200 * Double(k) / 1200)
            XCTAssertEqual(original, aliased, accuracy: 1e-11)
        }
    }

    func testZeroPhaseSamplingCollapsesAtNyquistAndIntegerRateMultiples() {
        var state = LabState(kind: .sampling)
        state.set(id: "sampleRate", value: 1200)
        for frequency in [600.0, 1200.0, 1800.0, 2400.0] {
            state.set(id: "frequency", value: frequency)
            let e = LabModel.evaluate(state)
            XCTAssertTrue(e.waveform.allSatisfy { abs($0) < 1e-10 })
            XCTAssertEqual(e.spectrum[0].amplitude, 0, "The folded-frequency marker must not imply a nonzero sampled sinusoid")
        }
    }

    func testScalePatternsAndInversionPitchClasses() {
        XCTAssertEqual(MusicMath.scaleOffsets(mode: 0), [0,2,4,5,7,9,11,12])
        XCTAssertEqual(MusicMath.scaleOffsets(mode: 1), [0,2,3,5,7,8,10,12])
        XCTAssertEqual(MusicMath.scaleOffsets(mode: 2), [0,2,3,5,7,8,11,12])
        XCTAssertEqual(MusicMath.scaleOffsets(mode: 3), [0,2,3,5,7,9,11,12])
        for quality in 0...3 {
            let chord = MusicMath.triad(root: 60, quality: quality)
            for inversion in 0...2 {
                let inverted = MusicMath.triad(root: 60, quality: quality, inversion: inversion)
                XCTAssertEqual(Set(chord.map { $0 % 12 }), Set(inverted.map { $0 % 12 }))
                XCTAssertEqual(inverted, inverted.sorted())
            }
        }
        XCTAssertEqual(MusicMath.triad(root: 60, inversion: 2), [67,72,76])
        XCTAssertEqual(MusicMath.motionCost(from: [60,64,67], to: [60,65,69]), 3)
        XCTAssertEqual(MusicMath.voiceMotion(from: [60,64,67], to: [60,65,69]), [0,1,2])
    }

    func testRhythmPhaseAndExactCycleConventions() {
        XCTAssertEqual(MusicMath.rhythmCoincidences(3, 2), 1)
        XCTAssertEqual(MusicMath.rhythmCoincidences(6, 4), 2)
        XCTAssertEqual(MusicMath.wrapPhase(-.pi / 2), 3 * .pi / 2, accuracy: 1e-12)
        XCTAssertEqual(MusicMath.cycles(time: 1.25, bpm: 96), 0, accuracy: 1e-12)
        var state = LabState(kind: .rhythm)
        state.set(id: "phase", value: 90)
        let recipe = LabModel.audio(state)
        XCTAssertEqual(recipe.rhythmCounts, [3,2])
        XCTAssertEqual(recipe.rhythmPhase, .pi / 2, accuracy: 1e-12)
        XCTAssertFalse(recipe.isSequenced)
        XCTAssertEqual(LabModel.evaluate(state).waveformSpan, 2.5, accuracy: 1e-12)
        XCTAssertEqual(LabModel.evaluate(state).waveform[0], 0, accuracy: 1e-12, "A quarter-cycle delay shifts both B pulses, not only the phase of a single B cycle")
    }

    func testAudioBoundsDiscardOutOfBandPartialsAndPreserveAttenuation() {
        let config = ToneConfiguration(voices: [AudioVoice(frequency: 1000, amplitudes: Array(repeating: 1, count: 8))]).sanitized(sampleRate: 8000)
        XCTAssertEqual(config.voices[0].amplitudes.prefix(3).reduce(0, +), 1, accuracy: 1e-12)
        XCTAssertTrue(config.voices[0].amplitudes.dropFirst(3).allSatisfy { $0 == 0 })
        let cutoffExact = ToneConfiguration(voices: [AudioVoice(frequency: 3600)]).sanitized(sampleRate: 8000)
        XCTAssertTrue(cutoffExact.voices.isEmpty)
        let invalid = ToneConfiguration(voices: [AudioVoice(frequency: .nan), AudioVoice(frequency: .infinity)]).sanitized(sampleRate: 48000)
        XCTAssertTrue(invalid.voices.isEmpty)
        XCTAssertTrue(ToneConfiguration(voices: [AudioVoice(frequency: 440)]).sanitized(sampleRate: .nan).voices.isEmpty)
        let many = ToneConfiguration(voices: Array(repeating: AudioVoice(frequency: 440, amplitudes: [1,1]), count: 8)).sanitized(sampleRate: 48000)
        XCTAssertEqual(many.voices.count, 4)
        XCTAssertEqual(many.voices.reduce(0.0) { $0 + $1.amplitudes.reduce(0, +) }, 1, accuracy: 1e-12)
    }

    func testCatalogAndAllModelBoundsAreFiniteWithHonestAxes() throws {
        XCTAssertEqual(LabCatalog.all.count, LabKind.allCases.count)
        XCTAssertEqual(Set(LabCatalog.all.map(\.kind)).count, LabKind.allCases.count)
        for kind in LabKind.allCases {
            let definition = LabCatalog.definition(for: kind)
            for variant in 0..<4 {
                var state = LabState(kind: kind)
                for parameter in definition.parameters {
                    state.values[parameter.id] = [parameter.defaultValue, parameter.range.lowerBound, parameter.range.upperBound, Double.nan][variant]
                }
                if variant == 3 { state.harmonics = [.nan, .infinity, -1, 4]; state.steps = [-20,999]; state.notes = [-1,999,60,60] }
                let e = LabModel.evaluate(state)
                XCTAssertEqual(e.waveform.count, 256, kind.rawValue)
                XCTAssertTrue(e.waveform.allSatisfy { $0.isFinite && abs($0) <= 1.000001 }, kind.rawValue)
                XCTAssertTrue(e.readouts.allSatisfy { $0.value.isFinite }, kind.rawValue)
                XCTAssertTrue(e.spectrum.allSatisfy { $0.frequency.isFinite && $0.amplitude.isFinite }, kind.rawValue)
                XCTAssertTrue(e.waveformSpan.isFinite && e.waveformSpan > 0, kind.rawValue)
                XCTAssertFalse(e.waveformCaption.isEmpty)
                XCTAssertFalse(e.spectrumCaption.isEmpty)
                XCTAssertFalse(e.equation.isEmpty)
                XCTAssertFalse(e.limitation.isEmpty)
                XCTAssertFalse(e.prediction.prompt.isEmpty)
                XCTAssertTrue(e.prediction.answer.isFinite)
                let audio = LabModel.audio(state).sanitized(sampleRate: 48000)
                for voice in audio.voices {
                    XCTAssertTrue(voice.frequency >= 20 && voice.frequency < 21600)
                    XCTAssertEqual(voice.amplitudes.count, 8)
                    for (i, amplitude) in voice.amplitudes.enumerated() where amplitude > 0 { XCTAssertLessThan(voice.frequency * Double(i + 1), 21600) }
                }
            }
            let original = LabState(kind: kind)
            let restored = try JSONDecoder().decode(LabState.self, from: JSONEncoder().encode(original))
            XCTAssertEqual(restored, original)
        }
    }

    func testCompositionUsesActualStepsAndOccupancySpectrum() {
        var state = LabState(kind: .composition)
        state.steps = [60,60,64,-1] + Array(repeating: -1, count: 12)
        let recipe = LabModel.audio(state)
        XCTAssertEqual(recipe.stepNotes, state.steps)
        XCTAssertTrue(recipe.isSequenced)
        let e = LabModel.evaluate(state)
        XCTAssertEqual(e.spectrum.count, 2)
        XCTAssertEqual(e.spectrum[0].amplitude, 2.0/3, accuracy: 1e-12)
        XCTAssertEqual(e.spectrum[1].amplitude, 1.0/3, accuracy: 1e-12)
        XCTAssertEqual(e.waveformUnit, "s")
        var transposedReference = state
        transposedReference.set(id: "root", value: 72)
        XCTAssertEqual(LabModel.audio(transposedReference).stepNotes, recipe.stepNotes, "Root editing never silently rewrites an artifact")
    }

    func testPredictionsApplyChangedScenarioRatherThanCopyCurrentValues() {
        let tone = LabModel.evaluate(LabState(kind: .tone))
        XCTAssertEqual(tone.prediction.answer, tone.readouts.first { $0.id == "period" }!.value / 2, accuracy: 1e-12)
        let resonance = LabModel.evaluate(LabState(kind: .resonance))
        XCTAssertEqual(resonance.prediction.answer, resonance.readouts.first { $0.id == "gain" }!.value / 2, accuracy: 1e-12)
        let filter = LabModel.evaluate(LabState(kind: .filter))
        XCTAssertEqual(filter.prediction.answer, filter.readouts.first { $0.id == "cutoff" }!.value / 2, accuracy: 1e-12)
        let room = LabModel.evaluate(LabState(kind: .room))
        XCTAssertEqual(room.prediction.answer, room.readouts.first { $0.id == "frequency" }!.value / 2, accuracy: 1e-12)
    }

    func testInvalidAndExtremeInputsDoNotLeakNonFiniteSamples() {
        for value in [Double.nan, .infinity, -.infinity, Double.greatestFiniteMagnitude] {
            XCTAssertTrue(MusicMath.additiveSample(time: value, frequency: 440, amplitudes: [1], phase: value).isFinite)
            XCTAssertTrue(MusicMath.beatEnvelope(difference: value, time: value).isFinite)
            XCTAssertTrue(MusicMath.wrapPhase(value).isFinite)
        }
        XCTAssertEqual(MusicMath.frequency(midi: Int.max), 0)
        XCTAssertTrue(MusicMath.frequency(midi: 100, a4: .greatestFiniteMagnitude).isFinite)
        XCTAssertTrue(MusicMath.midi(frequency: .leastNonzeroMagnitude, a4: .greatestFiniteMagnitude).isFinite)
        XCTAssertTrue(MusicMath.stringFrequency(length: .leastNonzeroMagnitude, tension: .greatestFiniteMagnitude, density: .leastNonzeroMagnitude).isFinite)
        XCTAssertTrue(MusicMath.rcCutoff(resistance: .leastNonzeroMagnitude, capacitance: .leastNonzeroMagnitude).isFinite)
    }
}
