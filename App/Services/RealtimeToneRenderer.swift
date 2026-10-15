import AVFoundation
import Foundation
import HarmonicCore
import Synchronization

/// Each cell is allocated before playback. The render callback only loads/stores
/// atomic scalars; it never waits for a writer or constructs a configuration array.
nonisolated private final class AtomicWord: Sendable {
    private let word: Atomic<UInt64>
    init(_ value: UInt64 = 0) { word = Atomic(value) }
    func load() -> UInt64 { word.load(ordering: .sequentiallyConsistent) }
    func store(_ value: UInt64) { word.store(value, ordering: .sequentiallyConsistent) }
}

nonisolated private struct PartialRequest {
    var frequency = 0.0
    var amplitude = 0.0
    var phase = 0.0
    var decay = 0.0
}

nonisolated private struct RenderRequest {
    var revision: UInt64 = 0
    var playSerial: UInt64 = 0
    var wanted = false
    var duration = 12.0
    var volume = 0.22
    var bpm = 96.0
    var mode = 0
    var partialCount = 0
    var stepCount = 0
    var rhythmA = 0
    var rhythmB = 0
    var rhythmPhase = 0.0
}

nonisolated private final class ToneCommandMailbox: Sendable {
    private let sequence = AtomicWord()
    private let words = (0..<12).map { _ in AtomicWord() }
    private let partials = (0..<128).map { _ in AtomicWord() }
    private let steps = (0..<16).map { _ in AtomicWord(UInt64(bitPattern: -1)) }

    func publish(_ configuration: ToneConfiguration, revision: UInt64,
                 playSerial: UInt64, wanted: Bool, duration: Double) {
        let before = sequence.load()
        sequence.store(before &+ 1)
        let rhythmic = configuration.rhythmCounts.count >= 2
        let sequenced = configuration.isSequenced && !configuration.stepNotes.isEmpty && !rhythmic
        let voices = sequenced ? Array(configuration.voices.prefix(1)) : configuration.voices
        var partialCount = 0
        for voice in voices.prefix(4) {
            for (index, amplitude) in voice.amplitudes.prefix(8).enumerated() {
                let slot = partialCount * 4
                partials[slot].store((voice.frequency * Double(index + 1)).bitPattern)
                partials[slot + 1].store(amplitude.bitPattern)
                partials[slot + 2].store((voice.phase * Double(index + 1)).bitPattern)
                partials[slot + 3].store(voice.decay.bitPattern)
                partialCount += 1
            }
        }
        let values: [UInt64] = [revision, playSerial, wanted ? 1 : 0,
            duration.bitPattern, configuration.volume.bitPattern, configuration.bpm.bitPattern,
            rhythmic ? 2 : sequenced ? 1 : 0, UInt64(partialCount),
            UInt64(min(16, configuration.stepNotes.count)),
            UInt64(rhythmic ? configuration.rhythmCounts[0] : 0),
            UInt64(rhythmic ? configuration.rhythmCounts[1] : 0), configuration.rhythmPhase.bitPattern]
        for index in words.indices { words[index].store(values[index]) }
        for index in 0..<16 {
            let note = index < configuration.stepNotes.count ? configuration.stepNotes[index] : -1
            steps[index].store(UInt64(bitPattern: Int64(note)))
        }
        sequence.store(before &+ 2)
    }

    func copy(to partialDestination: UnsafeMutablePointer<PartialRequest>,
              steps stepDestination: UnsafeMutablePointer<Int>, request: inout RenderRequest) -> Bool {
        for _ in 0..<2 {
            let before = sequence.load()
            guard before != 0, before.isMultiple(of: 2) else { continue }
            var next = RenderRequest()
            next.revision = words[0].load(); next.playSerial = words[1].load()
            next.wanted = words[2].load() != 0
            next.duration = Double(bitPattern: words[3].load())
            next.volume = Double(bitPattern: words[4].load())
            next.bpm = Double(bitPattern: words[5].load())
            next.mode = Int(words[6].load()); next.partialCount = Int(words[7].load())
            next.stepCount = Int(words[8].load())
            next.rhythmA = Int(words[9].load()); next.rhythmB = Int(words[10].load())
            next.rhythmPhase = Double(bitPattern: words[11].load())
            for index in 0..<next.partialCount {
                let slot = index * 4
                partialDestination[index] = PartialRequest(
                    frequency: Double(bitPattern: partials[slot].load()),
                    amplitude: Double(bitPattern: partials[slot + 1].load()),
                    phase: Double(bitPattern: partials[slot + 2].load()),
                    decay: Double(bitPattern: partials[slot + 3].load()))
            }
            for index in 0..<next.stepCount { stepDestination[index] = Int(Int64(bitPattern: steps[index].load())) }
            guard before == sequence.load() else { continue }
            request = next
            return true
        }
        return false
    }
}

nonisolated struct HarmonicAudioTelemetry: Sendable {
    var requestedRevision: UInt64 = 0
    var appliedRevision: UInt64 = 0
    var isRendering = false
    var sampleTime: UInt64 = 0
    var sampleRate = 48_000.0
    var peak = 0.0
    var rms = 0.0
    var status = "Ready"
    var sequenceStep = -1
    var rhythmCyclePhase = 0.0
    var renderedBlocks: UInt64 = 0
    var nonzeroSamples: UInt64 = 0
    var renderedHostTime = 0.0
}

nonisolated private final class ToneTelemetryMailbox: Sendable {
    private let sequence = AtomicWord()
    private let fields = (0..<11).map { _ in AtomicWord() }
    func publish(revision: UInt64, active: Bool, samples: UInt64, peak: Double, rms: Double,
                 step: Int, cycle: Double, blocks: UInt64, nonzero: UInt64, host: Double, finished: Bool) {
        let before = sequence.load(); sequence.store(before &+ 1)
        fields[0].store(revision); fields[1].store(active ? 1 : 0); fields[2].store(samples)
        fields[3].store(peak.bitPattern); fields[4].store(rms.bitPattern)
        fields[5].store(UInt64(bitPattern: Int64(step))); fields[6].store(cycle.bitPattern)
        fields[7].store(blocks); fields[8].store(nonzero); fields[9].store(host.bitPattern)
        fields[10].store(finished ? 1 : 0)
        sequence.store(before &+ 2)
    }
    func read(sampleRate: Double) -> HarmonicAudioTelemetry? {
        for _ in 0..<2 {
            let before = sequence.load()
            guard before != 0, before.isMultiple(of: 2) else { continue }
            var next = HarmonicAudioTelemetry()
            next.appliedRevision = fields[0].load(); next.isRendering = fields[1].load() != 0
            next.sampleTime = fields[2].load(); next.sampleRate = sampleRate
            next.peak = Double(bitPattern: fields[3].load()); next.rms = Double(bitPattern: fields[4].load())
            next.sequenceStep = Int(Int64(bitPattern: fields[5].load()))
            next.rhythmCyclePhase = Double(bitPattern: fields[6].load())
            next.renderedBlocks = fields[7].load(); next.nonzeroSamples = fields[8].load()
            next.renderedHostTime = Double(bitPattern: fields[9].load())
            let finished = fields[10].load() != 0
            guard before == sequence.load() else { continue }
            next.status = next.isRendering ? "Rendering" : finished ? "Audition complete" : "Stopped"
            return next
        }
        return nil
    }
}

nonisolated private struct RenderPartial {
    var phase = 0.0
    var offset = 0.0
    var offsetTarget = 0.0
    var frequency = 0.0
    var frequencyTarget = 0.0
    var amplitude = 0.0
    var amplitudeTarget = 0.0
    var decay = 0.0
    var decayLevel = 1.0
    var decayMultiplier = 1.0
}

/// Serial AVAudioSourceNode-owned oscillator state. The fixed 32-partial bank,
/// command scratch storage and telemetry cells are created before engine start.
nonisolated final class RealtimeToneRenderer: @unchecked Sendable {
    let sampleRate: Double
    private let commands = ToneCommandMailbox()
    private let telemetry = ToneTelemetryMailbox()
    private let requestPartials = UnsafeMutablePointer<PartialRequest>.allocate(capacity: 32)
    private let requestSteps = UnsafeMutablePointer<Int>.allocate(capacity: 16)
    private let steps = UnsafeMutablePointer<Int>.allocate(capacity: 16)
    private let oscillators = UnsafeMutablePointer<RenderPartial>.allocate(capacity: 32)
    private var request = RenderRequest()
    private var appliedRevision: UInt64 = 0
    private var playSerial: UInt64 = 0
    private var wanted = false
    private var finished = false
    private var deadline: UInt64 = 0
    private var samples: UInt64 = 0
    private var blocks: UInt64 = 0
    private var nonzero: UInt64 = 0
    private var gain = 0.0
    private var gainTarget = 0.0
    private var stepPosition = 0.0
    private var cyclePosition = 0.0
    private var currentStep = -1
    private var currentNote = -1
    private var lastSequenceSlot = -1
    private var countA = 0
    private var countB = 0
    private var phaseOffset = 0.0
    private var eventA = -1
    private var eventB = -1
    private var pulseAgeA = -1
    private var pulseAgeB = -1
    private let editBlend: Double
    private let gainStep: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        editBlend = 1 - exp(-1 / (0.008 * sampleRate))
        gainStep = 1 / (0.012 * sampleRate)
        requestPartials.initialize(repeating: .init(), count: 32)
        requestSteps.initialize(repeating: -1, count: 16)
        steps.initialize(repeating: -1, count: 16)
        oscillators.initialize(repeating: .init(), count: 32)
    }
    deinit {
        requestPartials.deinitialize(count: 32); requestPartials.deallocate()
        requestSteps.deinitialize(count: 16); requestSteps.deallocate()
        steps.deinitialize(count: 16); steps.deallocate()
        oscillators.deinitialize(count: 32); oscillators.deallocate()
    }
    func publish(configuration: ToneConfiguration, revision: UInt64, playSerial: UInt64,
                 wanted: Bool, duration: Double) {
        commands.publish(configuration, revision: revision, playSerial: playSerial, wanted: wanted, duration: duration)
    }
    func snapshot() -> HarmonicAudioTelemetry? { telemetry.read(sampleRate: sampleRate) }

    func render(isSilence: UnsafeMutablePointer<ObjCBool>, timestamp: UnsafePointer<AudioTimeStamp>,
                frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        if commands.copy(to: requestPartials, steps: requestSteps, request: &request), request.revision != appliedRevision {
            applyRequest()
        }
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        var peak = 0.0
        var energy = 0.0
        for frame in 0..<Int(frameCount) {
            if wanted, samples >= deadline { wanted = false; gainTarget = 0; finished = true }
            let active = wanted || gain > 0
            var value = 0.0
            if active {
                if gain < gainTarget { gain = min(gainTarget, gain + gainStep) }
                else if gain > gainTarget { gain = max(gainTarget, gain - gainStep) }
                if request.mode == 2 { value = rhythmSample() }
                else { value = oscillatorSample() }
                value *= gain
                stepPosition += request.bpm / (15 * sampleRate)
                cyclePosition += request.bpm / (240 * sampleRate)
                samples &+= 1
            }
            let output = Float(value.isFinite ? value : 0)
            peak = max(peak, abs(Double(output))); energy += Double(output) * Double(output)
            if abs(output) > 0.000001 { nonzero &+= 1 }
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                let channels = Int(buffer.mNumberChannels)
                for channel in 0..<channels { data[frame * channels + channel] = output }
            }
        }
        blocks &+= 1
        let host = timestamp.pointee.mHostTime == 0 ? 0 : AVAudioTime.seconds(forHostTime: timestamp.pointee.mHostTime)
        telemetry.publish(revision: appliedRevision, active: wanted || gain > 0, samples: samples,
            peak: peak, rms: sqrt(energy / Double(max(1, frameCount))), step: currentStep,
            cycle: cyclePosition.truncatingRemainder(dividingBy: 1), blocks: blocks, nonzero: nonzero,
            host: host, finished: finished)
        isSilence.pointee = ObjCBool(peak < 0.000001)
        return noErr
    }

    private func applyRequest() {
        let starting = request.playSerial != playSerial
        if starting {
            playSerial = request.playSerial
            samples = 0; stepPosition = 0; cyclePosition = 0; currentStep = -1; currentNote = -1
            lastSequenceSlot = -1
            eventA = -1; eventB = -1; pulseAgeA = -1; pulseAgeB = -1
            gain = 0; finished = false
            deadline = UInt64((request.duration * sampleRate).rounded())
            for index in 0..<32 { oscillators[index] = RenderPartial() }
        }
        wanted = request.wanted && !finished
        gainTarget = wanted ? request.volume : 0
        for index in 0..<32 {
            var oscillator = oscillators[index]
            if index < request.partialCount {
                let partial = requestPartials[index]
                let admissible = partial.frequency < sampleRate * 0.45
                // An omitted high partial must fade at its previous legal
                // frequency. Gliding its remaining amplitude above Nyquist
                // would create an audible alias during the edit ramp.
                if admissible { oscillator.frequencyTarget = partial.frequency }
                oscillator.amplitudeTarget = admissible ? partial.amplitude : 0
                if oscillator.decay != partial.decay || starting {
                    oscillator.decay = partial.decay
                    oscillator.decayMultiplier = partial.decay > 0 ? exp(-1 / (sampleRate * partial.decay)) : 1
                    // Preserve the envelope already sounded; the edited time
                    // constant governs its future slope rather than a gain jump.
                    if starting { oscillator.decayLevel = 1 }
                }
                if starting { oscillator.frequency = oscillator.frequencyTarget; oscillator.offset = partial.phase }
                let delta = partial.phase - oscillator.offset
                oscillator.offsetTarget = oscillator.offset + atan2(sin(delta), cos(delta))
            } else { oscillator.amplitudeTarget = 0 }
            oscillators[index] = oscillator
        }
        for index in 0..<request.stepCount { steps[index] = requestSteps[index] }
        // Recipe edits may arrive in the middle of a held step. Reapply that
        // step's pitch without resetting the preserved musical clock.
        if request.mode == 1 { currentStep = -1 }
        if !starting, (countA != request.rhythmA || countB != request.rhythmB || phaseOffset != request.rhythmPhase / (2 * .pi)) {
            eventA = Int(floor(cyclePosition * Double(max(1, request.rhythmA))))
            eventB = Int(floor((cyclePosition - request.rhythmPhase / (2 * .pi)) * Double(max(1, request.rhythmB))))
        }
        countA = request.rhythmA; countB = request.rhythmB; phaseOffset = request.rhythmPhase / (2 * .pi)
        if starting, phaseOffset > 0 { eventB = Int(floor(-phaseOffset * Double(max(1, countB)))) }
        appliedRevision = request.revision
    }

    private func oscillatorSample() -> Double {
        var envelope = 1.0
        if request.mode == 1, request.stepCount > 0 {
            let slot = Int(floor(stepPosition))
            let index = slot % request.stepCount
            let note = steps[index]
            if slot != lastSequenceSlot {
                lastSequenceSlot = slot
                // A sequence contains separate note onsets. Retrigger each
                // sounding slot's decay without resetting oscillator phase.
                // Recipe edits within this same slot only retune its targets.
                if note >= 0 {
                    for harmonic in 0..<min(8, request.partialCount) { oscillators[harmonic].decayLevel = 1 }
                }
            }
            if index != currentStep || note != currentNote {
                currentStep = index; currentNote = note
                if note >= 0 {
                    let fundamental = 440 * pow(2, Double(note - 69) / 12)
                    for harmonic in 0..<min(8, request.partialCount) {
                        let frequency = fundamental * Double(harmonic + 1)
                        let admissible = frequency < sampleRate * 0.45
                        if admissible { oscillators[harmonic].frequencyTarget = frequency }
                        oscillators[harmonic].amplitudeTarget = admissible ? requestPartials[harmonic].amplitude : 0
                    }
                }
            }
            let fraction = stepPosition - floor(stepPosition)
            let stepSeconds = 15 / request.bpm
            envelope = note < 0 ? 0 : min(1, min(fraction * stepSeconds / 0.01, (1 - fraction) * stepSeconds / 0.01))
        }
        var sample = 0.0
        for index in 0..<32 {
            var oscillator = oscillators[index]
            oscillator.frequency += (oscillator.frequencyTarget - oscillator.frequency) * editBlend
            oscillator.amplitude += (oscillator.amplitudeTarget - oscillator.amplitude) * editBlend
            if abs(oscillator.offsetTarget - oscillator.offset) > 0.000001 {
                oscillator.offset += (oscillator.offsetTarget - oscillator.offset) * editBlend
            }
            if oscillator.amplitude > 0.000001 {
                sample += sin(oscillator.phase + oscillator.offset) * oscillator.amplitude * oscillator.decayLevel
            }
            oscillator.decayLevel *= oscillator.decayMultiplier
            oscillator.phase += 2 * .pi * oscillator.frequency / sampleRate
            if oscillator.phase >= 2 * .pi { oscillator.phase.formTruncatingRemainder(dividingBy: 2 * .pi) }
            oscillators[index] = oscillator
        }
        return sample * envelope
    }

    private func rhythmSample() -> Double {
        let nextA = Int(floor(cyclePosition * Double(max(1, countA))))
        let nextB = Int(floor((cyclePosition - phaseOffset) * Double(max(1, countB))))
        if nextA > eventA { eventA = nextA; pulseAgeA = 0 }
        if nextB > eventB { eventB = nextB; pulseAgeB = 0 }
        return pulse(age: &pulseAgeA, frequency: 660) * 0.45 + pulse(age: &pulseAgeB, frequency: 330) * 0.45
    }
    private func pulse(age: inout Int, frequency: Double) -> Double {
        guard age >= 0 else { return 0 }
        let time = Double(age) / sampleRate
        guard time < 0.06 else { age = -1; return 0 }
        let envelope = min(1, time / 0.002) * exp(-time / 0.014) * min(1, (0.06 - time) / 0.008)
        age += 1
        return sin(2 * .pi * frequency * time) * envelope
    }
}
