import Foundation

/// SI calculations and Western tonal conventions. No audio, UI, or wall clock dependencies.
public enum MusicMath {
    public static let twoPi = 2 * Double.pi

    public static func bounded(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }

    public static func frequency(midi: Int, a4: Double = 440) -> Double {
        guard (-128...256).contains(midi), a4.isFinite, a4 > 0 else { return 0 }
        let result = a4 * pow(2, (Double(midi) - 69) / 12)
        return result.isFinite ? result : 0
    }

    public static func midi(frequency: Double, a4: Double = 440) -> Double {
        guard frequency.isFinite, frequency > 0, a4.isFinite, a4 > 0 else { return 0 }
        let result = 69 + 12 * log2(frequency / a4)
        return result.isFinite ? result : 0
    }

    public static func equalRatio(semitones: Double) -> Double {
        guard semitones.isFinite, abs(semitones) <= 120 else { return 1 }
        return pow(2, semitones / 12)
    }

    public static func cents(ratio: Double) -> Double {
        guard ratio.isFinite, ratio > 0 else { return 0 }
        return 1200 * log2(ratio)
    }

    public static func ratio(cents: Double) -> Double {
        guard cents.isFinite, abs(cents) <= 12_000 else { return 1 }
        return pow(2, cents / 1200)
    }

    /// One selected set of 5-limit/simple interval ratios. It is not a universal just scale.
    public static func simpleRatio(semitones: Int) -> Double {
        let s = min(48, max(-48, semitones))
        let ratios: [Double] = [1.0, 16.0/15, 9.0/8, 6.0/5, 5.0/4, 4.0/3,
                      45.0/32, 3.0/2, 8.0/5, 5.0/3, 9.0/5, 15.0/8]
        let octaves = Int(floor(Double(s) / 12))
        return ratios[(s % 12 + 12) % 12] * pow(2, Double(octaves))
    }

    public static func noteName(_ midi: Int) -> String {
        let p = (midi % 12 + 12) % 12
        let octave = Int(floor(Double(midi) / 12)) - 1
        return ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"][p] + String(octave)
    }

    public static func beatFrequency(_ first: Double, _ second: Double) -> Double {
        guard first.isFinite, second.isFinite else { return 0 }
        return abs(second - first)
    }

    /// Equal-amplitude pair, normalized to peak one. This is an amplitude envelope, not a new tone.
    public static func beatEnvelope(difference: Double, time: Double) -> Double {
        guard difference.isFinite, time.isFinite else { return 0 }
        let cycles = difference * time
        guard cycles.isFinite else { return 0 }
        return abs(cos(Double.pi * cycles.truncatingRemainder(dividingBy: 2)))
    }

    public static func stringFrequency(length: Double, tension: Double, density: Double, harmonic: Int = 1) -> Double {
        guard length.isFinite, tension.isFinite, density.isFinite,
              length > 0, density > 0, tension >= 0, harmonic > 0, harmonic <= 64 else { return 0 }
        let result = Double(harmonic) / (2 * length) * sqrt(tension / density)
        return result.isFinite ? result : 0
    }

    /// Normalized displacement of one ideal fixed-end mode, spatial position in metres.
    public static func stringShape(position: Double, length: Double, harmonic: Int, phase: Double = 0) -> Double {
        guard position.isFinite, length.isFinite, phase.isFinite, length > 0,
              harmonic > 0, harmonic <= 64 else { return 0 }
        let fraction = bounded(position / length, 0...1, fallback: 0)
        return sin(Double(harmonic) * .pi * fraction) * cos(phase.truncatingRemainder(dividingBy: twoPi))
    }

    public static func envelope(time: Double, decay: Double) -> Double {
        guard time.isFinite, decay.isFinite, decay > 0 else { return 0 }
        return exp(-max(0, time) / decay)
    }

    public static func halfLife(decay: Double) -> Double { decay.isFinite && decay > 0 ? decay * log(2) : 0 }

    public static func wrapPhase(_ radians: Double) -> Double {
        guard radians.isFinite else { return 0 }
        let r = radians.truncatingRemainder(dividingBy: twoPi)
        return r < 0 ? r + twoPi : r
    }

    /// Fold one real sinusoid into [0, Fs/2]. Exact Nyquist samples depend on initial phase.
    public static func aliasFrequency(frequency: Double, sampleRate: Double) -> Double {
        guard frequency.isFinite, sampleRate.isFinite, sampleRate > 0 else { return 0 }
        let r = abs(frequency).truncatingRemainder(dividingBy: sampleRate)
        return min(r, sampleRate - r)
    }

    public static func rcCutoff(resistance: Double, capacitance: Double) -> Double {
        guard resistance.isFinite, capacitance.isFinite, resistance > 0, capacitance > 0 else { return 0 }
        let result = 1 / (twoPi * resistance * capacitance)
        return result.isFinite ? result : 0
    }

    public static func lowPassGain(frequency: Double, cutoff: Double) -> Double {
        guard frequency.isFinite, cutoff.isFinite, cutoff > 0 else { return 0 }
        return 1 / hypot(1, frequency / cutoff)
    }

    public static func lowPassPhase(frequency: Double, cutoff: Double) -> Double {
        guard frequency.isFinite, cutoff.isFinite, cutoff > 0 else { return 0 }
        return -atan(frequency / cutoff)
    }

    /// Steady displacement / static displacement, for x'' + 2ζω0 x' + ω0²x = F/m.
    public static func resonanceGain(frequency: Double, natural: Double, damping: Double) -> Double {
        guard frequency.isFinite, natural.isFinite, damping.isFinite,
              frequency >= 0, natural > 0, damping > 0 else { return 0 }
        let r = frequency / natural
        return 1 / hypot(1 - r * r, 2 * damping * r)
    }

    public static func resonancePhase(frequency: Double, natural: Double, damping: Double) -> Double {
        guard frequency.isFinite, natural.isFinite, damping.isFinite,
              frequency >= 0, natural > 0, damping > 0 else { return 0 }
        let r = frequency / natural
        return -atan2(2 * damping * r, 1 - r * r)
    }

    public static func resonancePeak(natural: Double, damping: Double) -> Double {
        guard natural.isFinite, natural > 0, damping.isFinite, damping >= 0 else { return 0 }
        return damping < sqrt(0.5) ? natural * sqrt(1 - 2 * damping * damping) : 0
    }

    /// Major, natural minor, harmonic minor, ascending melodic minor; no key spelling inference.
    public static func scaleOffsets(mode: Int) -> [Int] {
        switch mode {
        case 1: return [0, 2, 3, 5, 7, 8, 10, 12]
        case 2: return [0, 2, 3, 5, 7, 8, 11, 12]
        case 3: return [0, 2, 3, 5, 7, 9, 11, 12]
        default: return [0, 2, 4, 5, 7, 9, 11, 12]
        }
    }

    public static func triadOffsets(quality: Int) -> [Int] {
        switch quality {
        case 1: return [0, 3, 7]
        case 2: return [0, 3, 6]
        case 3: return [0, 4, 8]
        default: return [0, 4, 7]
        }
    }

    public static func triad(root: Int, quality: Int = 0, inversion: Int = 0) -> [Int] {
        let r = min(108, max(12, root))
        var notes = triadOffsets(quality: quality).map { r + $0 }
        for _ in 0..<min(2, max(0, inversion)) { notes.append(notes.removeFirst() + 12) }
        return notes
    }

    /// Ordered lower/middle/upper voices; not a contrapuntal rule checker or optimal assignment.
    public static func voiceMotion(from: [Int], to: [Int]) -> [Int] {
        zip(from.sorted(), to.sorted()).map { $1 - $0 }
    }

    public static func motionCost(from: [Int], to: [Int]) -> Int {
        voiceMotion(from: from, to: to).reduce(0) { $0 + abs($1) }
    }

    public static func rhythmCoincidences(_ a: Int, _ b: Int) -> Int {
        var x = max(1, min(16, a)), y = max(1, min(16, b))
        while y != 0 { let remainder = x % y; x = y; y = remainder }
        return x
    }

    public static func cycles(time: Double, bpm: Double) -> Double {
        guard time.isFinite, bpm.isFinite, bpm > 0 else { return 0 }
        let value = time * bpm / 60
        return value - floor(value)
    }

    /// Pure normalized sum for plotting or test probes. Time is seconds; amplitudes are relative.
    public static func additiveSample(time: Double, frequency: Double, amplitudes: [Double], phase: Double = 0) -> Double {
        guard time.isFinite, frequency.isFinite, phase.isFinite else { return 0 }
        let cycles = frequency * time
        guard cycles.isFinite else { return 0 }
        let base = wrapPhase(twoPi * cycles.truncatingRemainder(dividingBy: 1) + wrapPhase(phase))
        let weights = amplitudes.prefix(8).map { bounded($0, 0...1, fallback: 0) }
        let total = max(1, weights.reduce(0, +))
        return weights.enumerated().reduce(0) { $0 + $1.element * sin(base * Double($1.offset + 1)) } / total
    }
}

/// Each entry is an integer harmonic of `frequency`; `phase` is the fundamental phase in radians.
/// `decay` is an amplitude time constant in seconds; zero means sustained.
public struct AudioVoice: Sendable, Equatable {
    public var frequency: Double
    public var amplitudes: [Double]
    public var phase: Double
    public var decay: Double
    public init(frequency: Double, amplitudes: [Double] = [1], phase: Double = 0, decay: Double = 0) {
        self.frequency = frequency; self.amplitudes = amplitudes; self.phase = phase; self.decay = decay
    }
}

/// Relative synthesis recipe. This does not describe acoustic pressure or device loudness.
public struct ToneConfiguration: Sendable, Equatable {
    public var voices: [AudioVoice]
    public var volume: Double
    public var bpm: Double
    /// Sixteenth-note MIDI slots in 4/4; -1 is a rest. A sequence begins at slot zero.
    public var stepNotes: [Int]
    public var isSequenced: Bool
    /// Two exact pulse trains per four-quarter-note cycle; phase offsets the second train.
    public var rhythmCounts: [Int]
    public var rhythmPhase: Double
    public init(voices: [AudioVoice] = [], volume: Double = 0.22, bpm: Double = 96, stepNotes: [Int] = [], isSequenced: Bool = false, rhythmCounts: [Int] = [], rhythmPhase: Double = 0) {
        self.voices = voices; self.volume = volume; self.bpm = bpm
        self.stepNotes = stepNotes; self.isSequenced = isSequenced
        self.rhythmCounts = rhythmCounts; self.rhythmPhase = rhythmPhase
    }

    /// Preserve filter attenuation; reduce only recipes whose combined absolute amplitude exceeds one.
    /// All actual partial frequencies are strictly below 0.45 Fs (a guard below Nyquist).
    public func sanitized(sampleRate: Double) -> ToneConfiguration {
        guard sampleRate.isFinite, sampleRate >= 100 else { return ToneConfiguration(volume: 0) }
        var result = self
        result.volume = MusicMath.bounded(volume, 0...0.5, fallback: 0.22)
        result.bpm = MusicMath.bounded(bpm, 30...240, fallback: 96)
        result.voices = voices.prefix(4).compactMap { voice in
            guard voice.frequency.isFinite, voice.frequency >= 20, voice.frequency < sampleRate * 0.45 else { return nil }
            var v = voice
            v.phase = MusicMath.wrapPhase(v.phase)
            v.decay = MusicMath.bounded(v.decay, 0...20, fallback: 0)
            v.amplitudes = (0..<8).map { i in
                guard i < voice.amplitudes.count, voice.frequency * Double(i + 1) < sampleRate * 0.45 else { return 0 }
                return MusicMath.bounded(voice.amplitudes[i], 0...1, fallback: 0)
            }
            return v.amplitudes.contains(where: { $0 > 0 }) ? v : nil
        }
        let total = result.voices.reduce(0.0) { $0 + $1.amplitudes.reduce(0, +) }
        if total > 1 {
            for i in result.voices.indices { result.voices[i].amplitudes = result.voices[i].amplitudes.map { $0 / total } }
        }
        result.stepNotes = stepNotes.prefix(16).map { $0 == -1 ? -1 : min(108, max(21, $0)) }
        if result.isSequenced && result.stepNotes.isEmpty { result.isSequenced = false }
        result.rhythmCounts = rhythmCounts.prefix(2).map { min(12, max(1, $0)) }
        result.rhythmPhase = MusicMath.wrapPhase(rhythmPhase)
        return result
    }
}
