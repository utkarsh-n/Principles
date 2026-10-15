import Foundation

public enum LabKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case tone, string, intervals, timbre, envelope, rhythm, scales, harmony, voiceLeading
    case resonance, sampling, filter, room, composition
    public var id: String { rawValue }
}

public struct LabParameter: Sendable {
    public var id: String
    public var title: String
    public var unit: String
    public var range: ClosedRange<Double>
    public var step: Double
    public var defaultValue: Double
    public var logarithmic: Bool
    public init(id: String, title: String, unit: String, range: ClosedRange<Double>, step: Double, defaultValue: Double, logarithmic: Bool = false) {
        self.id = id; self.title = title; self.unit = unit; self.range = range
        self.step = step; self.defaultValue = defaultValue; self.logarithmic = logarithmic
    }
    public func normalized(_ value: Double) -> Double {
        let v = MusicMath.bounded(value, range, fallback: defaultValue)
        guard step > 0 else { return v }
        return min(range.upperBound, max(range.lowerBound, range.lowerBound + ((v - range.lowerBound) / step).rounded() * step))
    }
}

public struct LabDefinition: Sendable, Identifiable {
    public var kind: LabKind
    public var title: String
    public var subtitle: String
    public var bridge: String
    public var parameters: [LabParameter]
    public var id: LabKind { kind }
    public init(kind: LabKind, title: String, subtitle: String, bridge: String, parameters: [LabParameter]) {
        self.kind = kind; self.title = title; self.subtitle = subtitle; self.bridge = bridge; self.parameters = parameters
    }
}

public enum LabCatalog {
    private static func p(_ id: String, _ title: String, _ unit: String, _ range: ClosedRange<Double>, _ value: Double, _ step: Double = 0, log: Bool = false) -> LabParameter {
        LabParameter(id: id, title: title, unit: unit, range: range, step: step, defaultValue: value, logarithmic: log)
    }
    public static let all: [LabDefinition] = [
        .init(kind: .tone, title: "One tone", subtitle: "A moving phase becomes a sound", bridge: "Frequency, period, sine and rotation", parameters: [p("frequency", "Frequency", "Hz", 55...1760, 220, log: true), p("amplitude", "Amplitude", "relative", 0...1, 0.8, 0.01), p("phase", "Phase", "°", 0...360, 0, 1)]),
        .init(kind: .string, title: "The string", subtitle: "Length and tension choose the pitch", bridge: "Boundary conditions and harmonic modes", parameters: [p("length", "Length", "m", 0.2...1.2, 0.65, 0.01), p("tension", "Tension", "N", 20...200, 100, 1), p("density", "Linear density", "kg/m", 0.001...0.01, 0.005, 0.0001), p("harmonic", "Mode", "", 1...8, 1, 1)]),
        .init(kind: .intervals, title: "Ratios & beats", subtitle: "Hear the difference between tuning systems", bridge: "Logarithms, rational ratios and interference", parameters: [p("frequency", "Root frequency", "Hz", 110...880, 220, log: true), p("semitones", "Interval", "semitones", 0...12, 7, 1), p("tuning", "Tuning", "0 equal · 1 ratio", 0...1, 0, 1), p("detune", "Detune", "cents", -30...30, 0, 0.5)]),
        .init(kind: .timbre, title: "Build a timbre", subtitle: "Same pitch, different harmonic recipe", bridge: "Fourier series and the shape of sound", parameters: [p("frequency", "Fundamental", "Hz", 55...880, 220, log: true)]),
        .init(kind: .envelope, title: "A fading note", subtitle: "A time constant changes how a sound ends", bridge: "Exponential decay and amplitude half-life", parameters: [p("frequency", "Pitch", "Hz", 110...880, 220, log: true), p("decay", "Time constant", "s", 0.1...3, 0.7, 0.05)]),
        .init(kind: .rhythm, title: "Rhythm & phase", subtitle: "Two exact pulse trains share one cycle", bridge: "Ratios, phase and greatest common divisors", parameters: [p("bpm", "Tempo", "BPM", 40...180, 96, 1), p("beatsA", "Pulses A", "per cycle", 1...12, 3, 1), p("beatsB", "Pulses B", "per cycle", 1...12, 2, 1), p("phase", "B phase", "°", 0...360, 0, 1)]),
        .init(kind: .scales, title: "Scales", subtitle: "A pattern of steps moves to a new root", bridge: "Transposition and modular arithmetic", parameters: [p("root", "Root", "MIDI", 48...72, 60, 1), p("mode", "Scale", "0 major · 1–3 minor", 0...3, 0, 1)]),
        .init(kind: .harmony, title: "Build a chord", subtitle: "Three notes, four qualities, three inversions", bridge: "Stacked intervals and pitch-class sets", parameters: [p("root", "Root", "MIDI", 48...72, 60, 1), p("quality", "Quality", "0 major · 1 minor · 2 dim · 3 aug", 0...3, 0, 1), p("inversion", "Inversion", "", 0...2, 0, 1)]),
        .init(kind: .voiceLeading, title: "Voice leading", subtitle: "Keep each voice close to where it was", bridge: "Ordered voices and absolute displacement", parameters: [p("root", "Start root", "MIDI", 48...72, 60, 1), p("targetRoot", "Target root", "MIDI", 48...72, 65, 1), p("targetQuality", "Target quality", "0 major · 1 minor · 2 dim · 3 aug", 0...3, 0, 1), p("targetInversion", "Target inversion", "", 0...2, 0, 1)]),
        .init(kind: .resonance, title: "Resonance", subtitle: "A small push can create a large response", bridge: "A driven damped oscillator and its frequency response", parameters: [p("natural", "Natural frequency", "Hz", 110...440, 220, log: true), p("drive", "Drive frequency", "Hz", 55...880, 220, log: true), p("damping", "Damping ratio", "ζ", 0.02...0.8, 0.08, 0.01)]),
        .init(kind: .sampling, title: "Sampling", subtitle: "Different waves can leave the same dots", bridge: "Nyquist, discrete time and aliasing", parameters: [p("frequency", "Original frequency", "Hz", 100...3000, 1000, 10), p("sampleRate", "Model sample rate", "samples/s", 200...8000, 1200, 50)]),
        .init(kind: .filter, title: "The RC filter", subtitle: "A capacitor softens a fast-changing signal", bridge: "Complex response, attenuation and phase", parameters: [p("frequency", "Tone frequency", "Hz", 55...1760, 220, log: true), p("resistance", "Resistance", "Ω", 100...10000, 1000, 100, log: true), p("capacitance", "Capacitance", "F", 1e-7...1e-5, 1e-6, log: true)]),
        .init(kind: .room, title: "A room mode", subtitle: "Room length sets a family of resonances", bridge: "Wavelength, sound speed and reflecting boundaries", parameters: [p("length", "Room length", "m", 2...10, 4, 0.1), p("soundSpeed", "Sound speed", "m/s", 320...355, 343, 1), p("mode", "Axial mode", "", 1...8, 1, 1)]),
        .init(kind: .composition, title: "Make a phrase", subtitle: "Compose sixteen steps and hear your choices", bridge: "A sequence turns pitch and rhythm into a reproducible artifact", parameters: [p("bpm", "Tempo", "BPM", 40...180, 96, 1), p("root", "Root", "MIDI", 48...72, 60, 1)])
    ]
    public static func definition(for kind: LabKind) -> LabDefinition { all.first { $0.kind == kind }! }
}

public struct LabState: Codable, Sendable, Equatable {
    public var kind: LabKind
    public var values: [String: Double]
    public var harmonics: [Double]
    public var steps: [Int]
    public var notes: [Int]
    public init(kind: LabKind) {
        self.kind = kind
        values = Dictionary(uniqueKeysWithValues: LabCatalog.definition(for: kind).parameters.map { ($0.id, $0.defaultValue) })
        harmonics = [1, 0.5, 0.25, 0.125, 0.08, 0.04, 0.02, 0.01]
        steps = [60, -1, 64, -1, 67, -1, 64, -1, 62, -1, 65, -1, 67, -1, 60, -1]
        notes = []
    }
    public func normalized() -> LabState {
        var result = self
        result.values = Dictionary(uniqueKeysWithValues: LabCatalog.definition(for: kind).parameters.map { ($0.id, $0.normalized(values[$0.id] ?? $0.defaultValue)) })
        result.harmonics = (0..<8).map { $0 < harmonics.count ? MusicMath.bounded(harmonics[$0], 0...1, fallback: 0) : 0 }
        result.steps = (0..<16).map { i in i < steps.count && steps[i] != -1 ? min(108, max(21, steps[i])) : -1 }
        var unique: [Int] = []
        for note in notes.prefix(8) where (21...108).contains(note) && !unique.contains(note) { unique.append(note) }
        result.notes = unique
        return result
    }
    public mutating func set(id: String, value: Double) {
        guard let p = LabCatalog.definition(for: kind).parameters.first(where: { $0.id == id }) else { return }
        values[id] = p.normalized(value)
    }
}

public struct LabReadout: Sendable, Identifiable {
    public var id: String
    public var title: String
    public var value: Double
    public var unit: String
    public init(id: String, title: String, value: Double, unit: String) { self.id = id; self.title = title; self.value = value; self.unit = unit }
}
public struct SpectrumBin: Sendable {
    public var frequency: Double
    public var amplitude: Double
    public init(frequency: Double, amplitude: Double) { self.frequency = frequency; self.amplitude = amplitude }
}
public struct PredictionTask: Sendable {
    public var prompt: String
    public var answer: Double
    public var unit: String
    public var tolerance: Double
    public init(prompt: String, answer: Double, unit: String, tolerance: Double) { self.prompt = prompt; self.answer = answer; self.unit = unit; self.tolerance = tolerance }
}
public struct LabEvaluation: Sendable {
    public var readouts: [LabReadout]
    public var equation: String
    public var explanation: String
    public var limitation: String
    public var waveform: [Double]
    public var waveformCaption: String
    public var waveformSpan: Double
    public var waveformUnit: String
    public var spectrumCaption: String
    public var spectrum: [SpectrumBin]
    public var prediction: PredictionTask
    public init(readouts: [LabReadout], equation: String, explanation: String, limitation: String, waveform: [Double], spectrum: [SpectrumBin], prediction: PredictionTask, waveformCaption: String = "Calculated relative amplitude", waveformSpan: Double = 1, waveformUnit: String = "s", spectrumCaption: String = "Calculated relative amplitudes; not microphone data") {
        self.readouts = readouts; self.equation = equation; self.explanation = explanation; self.limitation = limitation
        self.waveform = waveform; self.spectrum = spectrum; self.prediction = prediction
        self.waveformCaption = waveformCaption; self.waveformSpan = waveformSpan; self.waveformUnit = waveformUnit
        self.spectrumCaption = spectrumCaption
    }
}

public enum LabModel {
    private static func read(_ id: String, _ title: String, _ value: Double, _ unit: String = "") -> LabReadout { .init(id: id, title: title, value: value, unit: unit) }
    private static func task(_ prompt: String, _ answer: Double, _ unit: String = "", _ tolerance: Double = 0.5) -> PredictionTask { .init(prompt: "Hypothetical model change (may extend beyond control limits): " + prompt, answer: answer, unit: unit, tolerance: tolerance) }
    private static func curve(_ sample: (Double) -> Double) -> [Double] { (0..<256).map { sample(Double($0) / 255) } }
    private static func sine(_ phase: Double = 0, amplitude: Double = 1) -> [Double] { curve { amplitude * sin(6 * .pi * $0 + phase) } }
    private static func bins(_ frequency: Double, _ harmonics: [Double]) -> [SpectrumBin] {
        let total = max(1, harmonics.reduce(0, +))
        return harmonics.enumerated().filter { $0.element > 0 }.map { SpectrumBin(frequency: frequency * Double($0.offset + 1), amplitude: $0.element / total) }
    }
    public static func evaluate(_ input: LabState) -> LabEvaluation {
        let s = input.normalized()
        func v(_ id: String) -> Double { s.values[id] ?? 0 }
        var readings: [LabReadout] = []
        var equation = "", explanation = "", limitation = ""
        var waveform = sine(), spectrum: [SpectrumBin] = []
        var prediction = task("", 0)
        switch s.kind {
        case .tone:
            let f = v("frequency"), phase = v("phase") * .pi / 180
            readings = [read("frequency", "Frequency", f, "Hz"), read("period", "Period", 1000 / f, "ms"), read("angular", "Angular speed", MusicMath.twoPi * f, "rad/s"), read("energy", "Relative mean square", v("amplitude") * v("amplitude") / 2)]
            equation = "x(t) = A sin(2πft + φ) · T = 1/f"
            explanation = "One cycle is one complete turn. Doubling frequency halves its period. The trace spans three cycles with relative amplitude; audio runs at the chosen real frequency."
            limitation = "Synthesized mono sine; amplitude is relative digital level, not calibrated sound pressure or perceived loudness."
            waveform = sine(phase, amplitude: v("amplitude")); spectrum = [.init(frequency: f, amplitude: v("amplitude"))]
            prediction = task("If frequency doubles to \(Int(f * 2)) Hz, what is the new period?", 500 / f, "ms", 0.05)
        case .string:
            let n = Int(v("harmonic")), f1 = MusicMath.stringFrequency(length: v("length"), tension: v("tension"), density: v("density"))
            let f = f1 * Double(n)
            readings = [read("fundamental", "Fundamental", f1, "Hz"), read("frequency", "Selected mode", f, "Hz"), read("speed", "Wave speed", sqrt(v("tension") / v("density")), "m/s"), read("nodes", "Nodes including ends", Double(n + 1))]
            equation = "fₙ = n/(2L) √(T/μ) · yₙ(x) ∝ sin(nπx/L)"
            explanation = "Both ends are fixed, so allowed shapes contain whole numbers of half wavelengths. The trace shows spatial displacement along the full string; sound plays the selected mode."
            limitation = "Ideal flexible uniform string, small transverse displacement, fixed endpoints; stiffness, soundboard, coupling and real damping are excluded."
            waveform = curve { MusicMath.stringShape(position: $0 * v("length"), length: v("length"), harmonic: n) }
            spectrum = [.init(frequency: f, amplitude: 1)]
            prediction = task("With tension and density fixed, halve the string length. What is this mode's new frequency?", 2 * f, "Hz", 1)
        case .intervals:
            let root = v("frequency"), semitones = Int(v("semitones"))
            let ratio = (v("tuning") == 0 ? MusicMath.equalRatio(semitones: Double(semitones)) : MusicMath.simpleRatio(semitones: semitones)) * MusicMath.ratio(cents: v("detune"))
            let target = root * ratio, beats = MusicMath.beatFrequency(root, target)
            readings = [read("ratio", "Frequency ratio", ratio), read("cents", "Interval", MusicMath.cents(ratio: ratio), "cents"), read("target", "Upper frequency", target, "Hz"), read("beats", "Difference frequency", beats, "Hz")]
            equation = "f₂ = rf₁ · cents = 1200 log₂ r · Δf = |f₂ − f₁|"
            explanation = "Equal temperament spaces semitones evenly in logarithmic pitch. The ratio mode uses one disclosed simple-ratio table. The trace is the equal-amplitude beat envelope over four difference cycles, rather than an audio-rate waveform. Slow differences are heard as beats; wide intervals sound as two pitches."
            limitation = "No universal consonance score. A linear sum contains the original two tones, not a generated difference tone. Tuning preferences depend on music and instrument."
            waveform = beats > 1e-6 ? curve { MusicMath.beatEnvelope(difference: beats, time: $0 * 4 / beats) } : Array(repeating: 1, count: 256)
            spectrum = [.init(frequency: root, amplitude: 0.5), .init(frequency: target, amplitude: 0.5)]
            prediction = task("Raise only the upper tone by 10 Hz, holding the root fixed. What is the new difference frequency?", abs(target + 10 - root), "Hz", 0.1)
        case .timbre:
            let f = v("frequency"), weights = s.harmonics, sum = weights.reduce(0, +)
            let centroid = sum > 0 ? weights.enumerated().reduce(0) { $0 + Double($1.offset + 1) * f * $1.element } / sum : 0
            readings = [read("frequency", "Fundamental grid", f, "Hz"), read("partials", "Active partials", Double(weights.filter { $0 > 0 }.count)), read("centroid", "Amplitude-weighted centre", centroid, "Hz"), read("highest", "Highest active partial", Double((weights.lastIndex(where: { $0 > 0 }) ?? -1) + 1) * f, "Hz")]
            equation = "x(t) = Σ aₙ sin(2πnf₀t) / max(1, Σaₙ)"
            explanation = "Each bar sets an integer harmonic's relative starting amplitude. The trace spans three fundamental cycles. Audio and plot share the eight-weight recipe, with a bounded amplitude sum."
            limitation = "Eight stationary sinusoidal components, not a recorded instrument. The centre uses amplitude weights, not an FFT power spectrum or a perceptual brightness measurement."
            waveform = curve { MusicMath.additiveSample(time: $0 * 3 / f, frequency: f, amplitudes: weights) }
            spectrum = bins(f, weights)
            prediction = task("Keep the recipe but double the fundamental. What is harmonic 5's new frequency?", 10 * f, "Hz", 1)
        case .envelope:
            let tau = v("decay")
            readings = [read("timeConstant", "Amplitude time constant", tau, "s"), read("halfLife", "Amplitude half-life", MusicMath.halfLife(decay: tau), "s"), read("atOneSecond", "Amplitude at 1 s", MusicMath.envelope(time: 1, decay: tau)), read("frequency", "Carrier pitch", v("frequency"), "Hz")]
            equation = "A(t) = A₀e⁻ᵗ/τ · t½ = τ ln 2"
            explanation = "The trace is the amplitude envelope over four time constants. At τ the amplitude is 1/e of its initial value; at τ ln 2 it is half. Audio keeps the carrier's pitch while its amplitude falls."
            limitation = "Illustrative exponential amplitude decay, not a fitted instrument or full damping model. Squared amplitude decays twice as quickly; perceived loudness is different."
            waveform = curve { MusicMath.envelope(time: $0 * 4 * tau, decay: tau) }; spectrum = [.init(frequency: v("frequency"), amplitude: 1)]
            prediction = task("Double the time constant. What will the new amplitude half-life be?", 2 * MusicMath.halfLife(decay: tau), "s", 0.05)
        case .rhythm:
            let a = Int(v("beatsA")), b = Int(v("beatsB")), cycle = 240 / v("bpm")
            let aligned = v("phase") == 0 || v("phase") == 360
            readings = [read("cycle", "Four-beat cycle", cycle, "s"), read("rateA", "A pulse rate", Double(a) / cycle, "Hz"), read("rateB", "B pulse rate", Double(b) / cycle, "Hz"), read("alignedCoincidences", "Coincidences at zero phase", Double(MusicMath.rhythmCoincidences(a, b)))]
            equation = "Tcycle = 240/BPM · fA = A/Tcycle · fB = B/Tcycle"
            explanation = "\(a) and \(b) pulses fit the same four-quarter-note cycle. The trace shows two unit-circle projections (A and phase-shifted B), while audio plays exact pulse trains. \(aligned ? "The origins are aligned." : "B has a phase offset; the coincidence readout is the zero-phase comparison.")"
            limitation = "Ideal evenly spaced pulses; no swing or performed microtiming. The common-divisor coincidence count applies to aligned origins, excluding the duplicate cycle endpoint."
            waveform = curve { 0.5 * (sin(MusicMath.twoPi * Double(a) * $0) + sin(MusicMath.twoPi * Double(b) * ($0 - v("phase") / 360))) }
            prediction = task("Double tempo, keeping pulse counts. What is A's new pulse rate?", 2 * Double(a) / cycle, "Hz", 0.05)
        case .scales:
            let root = Int(v("root")), offsets = MusicMath.scaleOffsets(mode: Int(v("mode"))), notes = offsets.map { root + $0 }
            readings = [read("root", "Root frequency", MusicMath.frequency(midi: root), "Hz"), read("third", "Third degree", MusicMath.frequency(midi: notes[2]), "Hz"), read("seventh", "Seventh degree", Double(offsets[6]), "semitones"), read("octave", "Octave ratio", 2)]
            equation = "pitch class = MIDI mod 12 · f(m) = 440 × 2^((m−69)/12)"
            explanation = "\(scaleName(Int(v("mode")))) steps: \(zip(offsets, offsets.dropFirst()).map { String($1 - $0) }.joined(separator: " · ")). Notes: \(notes.map(MusicMath.noteName).joined(separator: " · ")). The trace spans three root cycles. Tap keys to hear degrees, or compare patterns at a new root."
            limitation = "Western twelve-tone equal temperament; keyboard labels use simplified enharmonic names rather than full key-aware notation. Melodic minor here is its ascending form."
            spectrum = notes.map { .init(frequency: MusicMath.frequency(midi: $0), amplitude: 1 / 8) }
            prediction = task("Transpose the entire scale up an octave. What is the new root frequency?", MusicMath.frequency(midi: root) * 2, "Hz", 1)
        case .harmony:
            let root = Int(v("root")), quality = Int(v("quality")), inversion = Int(v("inversion")), notes = MusicMath.triad(root: root, quality: quality, inversion: inversion)
            readings = [read("root", "Root pitch", MusicMath.frequency(midi: root), "Hz"), read("bass", "Bass pitch", MusicMath.frequency(midi: notes[0]), "Hz"), read("span", "Outer span", Double(notes[2] - notes[0]), "semitones"), read("voices", "Chord voices", 3)]
            equation = "Major [0,4,7] · minor [0,3,7] · diminished [0,3,6] · augmented [0,4,8]"
            explanation = "\(qualityName(quality)) triad: \(notes.map(MusicMath.noteName).joined(separator: " · ")). An inversion raises a lower note by an octave without changing its pitch class. The trace combines these three tones in a 10 ms slice."
            limitation = "Equal-tempered synthesized triads. Quality names are tonal conventions; they are not universal claims about emotion or consonance. Keyboard note names are simplified enharmonic labels."
            waveform = chordWave(notes); spectrum = notes.map { .init(frequency: MusicMath.frequency(midi: $0), amplitude: 1 / 3) }
            prediction = task("Transpose this chord up an octave. What is the new bass frequency?", MusicMath.frequency(midi: notes[0]) * 2, "Hz", 1)
        case .voiceLeading:
            let from = MusicMath.triad(root: Int(v("root"))), to = MusicMath.triad(root: Int(v("targetRoot")), quality: Int(v("targetQuality")), inversion: Int(v("targetInversion")))
            let motion = MusicMath.voiceMotion(from: from, to: to)
            let rootTarget = MusicMath.triad(root: Int(v("targetRoot")), quality: Int(v("targetQuality")))
            readings = [read("motion", "Total ordered motion", Double(MusicMath.motionCost(from: from, to: to)), "semitones"), read("rootMotion", "Root-position comparison", Double(MusicMath.motionCost(from: from, to: rootTarget)), "semitones"), read("common", "Common pitch classes", Double(Set(from.map { $0 % 12 }).intersection(Set(to.map { $0 % 12 })).count)), read("largest", "Largest voice movement", Double(motion.map(abs).max() ?? 0), "semitones")]
            equation = "Motion = Σ |targetᵢ − startᵢ|, with voices ordered low to high"
            explanation = "\(from.map(MusicMath.noteName).joined(separator: " · ")) → \(to.map(MusicMath.noteName).joined(separator: " · ")). Ordered voice changes: \(motion.map { String(format: "%+d", $0) }.joined(separator: " · ")) semitones. The trace and sound show the target chord."
            limitation = "A disclosed ordered-displacement comparison, not optimized assignment, full counterpoint, or a judgement that less motion always makes better music."
            waveform = chordWave(to); spectrum = to.map { .init(frequency: MusicMath.frequency(midi: $0), amplitude: 1 / 3) }
            let shifted = to.map { $0 + 12 }
            prediction = task("Raise every target voice one octave. What is the new total ordered motion from the same start?", Double(MusicMath.motionCost(from: from, to: shifted)), "semitones", 0.1)
        case .resonance:
            let f0 = v("natural"), f = v("drive"), z = v("damping"), gain = MusicMath.resonanceGain(frequency: f, natural: f0, damping: z)
            readings = [read("gain", "Displacement / static", gain, "×"), read("phase", "Phase lag", MusicMath.resonancePhase(frequency: f, natural: f0, damping: z) * 180 / .pi, "°"), read("peak", "Response peak", MusicMath.resonancePeak(natural: f0, damping: z), "Hz"), read("quality", "Oscillator Q", 1 / (2 * z))]
            equation = "G = 1/√[(1−r²)² + (2ζr)²], r = f/f₀"
            explanation = "Driving near the response peak increases steady displacement. Damping removes energy and broadens the response. The trace spans three drive cycles; trace/audio amplitude uses a fixed 1/26 scale of this response. A peak of 0 Hz means the maximum is at DC."
            limitation = "Linear single oscillator in steady state; no transient buildup, nonlinear saturation or material failure. Q = 1/(2ζ); the response peak differs from natural frequency when damping is appreciable."
            waveform = sine(MusicMath.resonancePhase(frequency: f, natural: f0, damping: z), amplitude: min(1, gain / 26)); spectrum = [.init(frequency: f, amplitude: gain / 26)]
            prediction = task("Double damping and drive exactly at the natural frequency. What is displacement/static gain?", 1 / (4 * z), "×", 0.05)
        case .sampling:
            let f = v("frequency"), fs = v("sampleRate"), alias = MusicMath.aliasFrequency(frequency: f, sampleRate: fs)
            readings = [read("nyquist", "Model Nyquist", fs / 2, "Hz"), read("alias", "Folded frequency", alias, "Hz"), read("samplesPerCycle", "Samples / original cycle", fs / f), read("margin", "Nyquist minus original", fs / 2 - f, "Hz")]
            equation = "x[k] = sin(2πfk/Fs) · alias = min(f mod Fs, Fs − (f mod Fs))"
            explanation = "The trace is 256 exact samples at the chosen model sample rate. Above model Nyquist, the sampled sine is indistinguishable from a lower-frequency sine with a possible phase reversal. Sound plays the original physical frequency through the device's real, separately guarded sample rate."
            limitation = "Single-tone sampling illustration; model sample rate is not the device audio rate. Exact Nyquist can collapse to zero or depend on phase. No claim of reconstructing arbitrary non-bandlimited signals."
            waveform = curve { sin(MusicMath.twoPi * f * ($0 * 255 / fs)) }
            let zeroPhaseCollapse = alias < 1e-8 || abs(alias - fs / 2) < 1e-8
            spectrum = [.init(frequency: alias, amplitude: zeroPhaseCollapse ? 0 : 1)]
            prediction = task("Increase the model sampling rate to \(Int(4 * f)) samples/s. What is Nyquist?", 2 * f, "Hz", 1)
        case .filter:
            let f = v("frequency"), tau = v("resistance") * v("capacitance"), cutoff = MusicMath.rcCutoff(resistance: v("resistance"), capacitance: v("capacitance")), gain = MusicMath.lowPassGain(frequency: f, cutoff: cutoff), phase = MusicMath.lowPassPhase(frequency: f, cutoff: cutoff)
            readings = [read("cutoff", "Cutoff", cutoff, "Hz"), read("timeConstant", "RC time constant", tau * 1000, "ms"), read("gain", "Amplitude gain", gain, "×"), read("phase", "Phase lag", phase * 180 / .pi, "°")]
            equation = "H(jω) = 1/(1+jωRC) · fc = 1/(2πRC)"
            explanation = "The output is measured across the capacitor. Faster changes are attenuated and phase-shifted. Trace (three input cycles) and audio use the same exact steady-state sine gain/phase; at cutoff gain is 1/√2 and phase is −45°."
            limitation = "Ideal unloaded first-order RC, steady sinusoidal input; no source resistance, component tolerance or transient charging. Digital amplitude is relative, not measured voltage."
            waveform = sine(phase, amplitude: gain); spectrum = [.init(frequency: f, amplitude: gain)]
            prediction = task("Double resistance, holding capacitance fixed. What is the new cutoff?", cutoff / 2, "Hz", max(0.1, cutoff * 0.005))
        case .room:
            let n = Int(v("mode")), fundamental = v("soundSpeed") / (2 * v("length")), f = fundamental * Double(n)
            readings = [read("frequency", "Axial frequency", f, "Hz"), read("fundamental", "First axial mode", fundamental, "Hz"), read("wavelength", "Wavelength", 2 * v("length") / Double(n), "m"), read("antinodes", "Pressure antinodes", Double(n + 1))]
            equation = "fₙ = nc/(2L) · p(x) ∝ cos(nπx/L)"
            explanation = "Perfectly rigid reflecting ends are pressure antinodes. The trace shows normalized pressure along one room axis; it is not a map from this phone's microphone. Sound plays the selected ideal axial frequency."
            limitation = "One-dimensional ideal rectangular axis; real rooms have three-dimensional modes, losses, furniture and coupled sources. No calibrated loudness or room measurement."
            waveform = curve { cos(Double(n) * .pi * $0) }; spectrum = [.init(frequency: f, amplitude: 1)]
            prediction = task("Double room length, keeping sound speed and mode fixed. What is the new frequency?", f / 2, "Hz", 0.5)
        case .composition:
            let active = s.steps.filter { $0 >= 0 }, unique = Set(active), duration = 240 / v("bpm")
            readings = [read("notes", "Sounding steps", Double(active.count)), read("unique", "Distinct MIDI pitches", Double(unique.count)), read("duration", "Four-beat phrase", duration, "s"), read("stepDuration", "Sixteenth-note step", 15 / v("bpm"), "s")]
            equation = "Δtstep = 15/BPM · Tphrase = 16Δtstep"
            explanation = "Sixteen explicit MIDI/rest steps repeat as one 4/4 bar. The trace encodes each step's equal-tempered semitone distance above the chosen root (rests at zero), rather than an audio waveform. Saved recipes retain exact notes and tempo."
            limitation = "A discrete equal-tempered monophonic sequencer. Root is an editing/reference pitch; changing it does not silently transpose stored MIDI notes. No harmonic correctness or artistic quality score."
            waveform = (0..<256).map { i in let note = s.steps[min(15, i / 16)]; return note < 0 ? 0 : Double(note - Int(v("root"))) / 60 }
            // Spectrum expresses note occupancy, not measured Fourier energy.
            spectrum = unique.sorted().map { note in .init(frequency: MusicMath.frequency(midi: note), amplitude: Double(active.filter { $0 == note }.count) / Double(max(1, active.count))) }
            prediction = task("Double tempo while keeping all sixteen steps. What is the new phrase duration?", duration / 2, "s", 0.05)
        }
        var caption = "Calculated relative amplitude · three cycles", span = 3 / max(1, v("frequency")), unit = "s"
        var spectrumCaption = "Calculated starting relative amplitude · not microphone data"
        switch s.kind {
        case .string: caption = "Ideal mode displacement along string"; span = v("length"); unit = "m"
        case .intervals:
            let difference = readings.first { $0.id == "beats" }?.value ?? 0
            span = difference > 1e-6 ? 4 / difference : 1
            caption = "Equal-amplitude interference envelope · four difference cycles"
        case .envelope: caption = "Amplitude envelope · four time constants"; span = 4 * v("decay")
        case .rhythm: caption = "Two phase projections over one four-beat cycle"; span = 240 / v("bpm")
        case .scales: span = 3 / MusicMath.frequency(midi: Int(v("root"))); spectrumCaption = "Reference scale pitches · equal display weights, not a simultaneous recording"
        case .harmony, .voiceLeading:
            caption = "Reference chord fundamentals · 10 ms slice; audition adds illustrative harmonics"
            spectrumCaption = "Reference fundamentals only · audition also includes harmonic partials"
            span = 0.01
        case .resonance: caption = "Steady response, amplitude scaled by 1/26"; span = 3 / v("drive"); spectrumCaption = "Steady response / 26 · fixed display and audio scale"
        case .sampling: caption = "256 exact model samples, connected for inspection"; span = 255 / v("sampleRate"); spectrumCaption = "Mathematically folded frequency · audio plays original tone"
        case .room: caption = "Ideal axial pressure along room length"; span = v("length"); unit = "m"
        case .composition: caption = "Step pitch offset / 60 semitones; rest shown at zero"; span = 240 / v("bpm"); spectrumCaption = "Fraction of sounding steps at each pitch · not spectral energy"
        case .filter: caption = "Steady output amplitude across capacitor · three input cycles"
        case .tone, .timbre: break
        }
        return LabEvaluation(readouts: readings, equation: equation, explanation: explanation, limitation: limitation, waveform: waveform, spectrum: spectrum, prediction: prediction, waveformCaption: caption, waveformSpan: span, waveformUnit: unit, spectrumCaption: spectrumCaption)
    }

    public static func audio(_ input: LabState) -> ToneConfiguration {
        let s = input.normalized()
        func v(_ id: String) -> Double { s.values[id] ?? 0 }
        func voice(_ frequency: Double, _ amplitudes: [Double] = [1], phase: Double = 0, decay: Double = 0) -> AudioVoice { .init(frequency: frequency, amplitudes: amplitudes, phase: phase, decay: decay) }
        switch s.kind {
        case .tone: return .init(voices: [voice(v("frequency"), [v("amplitude")], phase: v("phase") * .pi / 180)])
        case .string: return .init(voices: [voice(MusicMath.stringFrequency(length: v("length"), tension: v("tension"), density: v("density"), harmonic: Int(v("harmonic"))))])
        case .intervals:
            let r = (v("tuning") == 0 ? MusicMath.equalRatio(semitones: v("semitones")) : MusicMath.simpleRatio(semitones: Int(v("semitones")))) * MusicMath.ratio(cents: v("detune"))
            return .init(voices: [voice(v("frequency"), [0.5]), voice(v("frequency") * r, [0.5])])
        case .timbre: return .init(voices: [voice(v("frequency"), s.harmonics)])
        case .envelope: return .init(voices: [voice(v("frequency"), [1, 0.3, 0.12], decay: v("decay"))])
        case .rhythm: return .init(bpm: v("bpm"), rhythmCounts: [Int(v("beatsA")), Int(v("beatsB"))], rhythmPhase: v("phase") * .pi / 180)
        case .scales:
            let notes = MusicMath.scaleOffsets(mode: Int(v("mode"))).map { Int(v("root")) + $0 }
            let slots = notes.flatMap { [$0, -1] }
            return .init(voices: [voice(MusicMath.frequency(midi: Int(v("root"))), [1, 0.2, 0.08], decay: 0.3)], stepNotes: slots, isSequenced: true)
        case .harmony:
            let notes = MusicMath.triad(root: Int(v("root")), quality: Int(v("quality")), inversion: Int(v("inversion")))
            return .init(voices: notes.prefix(4).map { voice(MusicMath.frequency(midi: $0), [1, 0.2, 0.08]) })
        case .voiceLeading:
            let notes = MusicMath.triad(root: Int(v("targetRoot")), quality: Int(v("targetQuality")), inversion: Int(v("targetInversion")))
            return .init(voices: notes.map { voice(MusicMath.frequency(midi: $0), [1, 0.2, 0.08]) })
        case .resonance:
            let gain = MusicMath.resonanceGain(frequency: v("drive"), natural: v("natural"), damping: v("damping"))
            return .init(voices: [voice(v("drive"), [min(1, gain / 26)], phase: MusicMath.resonancePhase(frequency: v("drive"), natural: v("natural"), damping: v("damping")))])
        case .sampling: return .init(voices: [voice(v("frequency"))])
        case .filter:
            let cutoff = MusicMath.rcCutoff(resistance: v("resistance"), capacitance: v("capacitance"))
            return .init(voices: [voice(v("frequency"), [MusicMath.lowPassGain(frequency: v("frequency"), cutoff: cutoff)], phase: MusicMath.lowPassPhase(frequency: v("frequency"), cutoff: cutoff))])
        case .room: return .init(voices: [voice(v("soundSpeed") / (2 * v("length")) * v("mode"))])
        case .composition: return .init(voices: [voice(MusicMath.frequency(midi: Int(v("root"))), s.harmonics, decay: 0.3)], bpm: v("bpm"), stepNotes: s.steps, isSequenced: true)
        }
    }
    private static func scaleName(_ mode: Int) -> String { ["Major", "Natural minor", "Harmonic minor", "Ascending melodic minor"][min(3, max(0, mode))] }
    private static func qualityName(_ quality: Int) -> String { ["Major", "Minor", "Diminished", "Augmented"][min(3, max(0, quality))] }
    private static func chordWave(_ notes: [Int]) -> [Double] {
        curve { x in notes.reduce(0.0) { $0 + sin(MusicMath.twoPi * MusicMath.frequency(midi: $1) * x * 0.01) } / Double(max(1, notes.count)) }
    }
}
