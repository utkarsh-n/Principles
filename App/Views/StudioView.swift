import SwiftUI
import HarmonicCore

struct StudioView: View {
    var session: DegreeSession
    var audio: HarmonicAudioEngine
    var feedback: HarmonicFeedback
    var motion: HarmonicMotion
    @State private var prediction = false
    @State private var saving = false
    @State private var selectedStep: Int?
    @State private var editorParameter: LabParameter?
    @State private var editorValue = ""
    @Environment(\.dynamicTypeSize) private var dynamicType

    private var definition: LabDefinition { LabCatalog.definition(for: session.state.kind) }
    var body: some View {
        DegreeScroll {
            HStack(alignment: .top) {
                DegreeHeader(eyebrow: "The fusion studio", title: definition.title, subtitle: definition.bridge)
                Menu {
                    ForEach(LabKind.allCases, id: \.rawValue) { kind in
                        Button(LabCatalog.definition(for: kind).title, systemImage: kind.symbol) { audio.stop(); session.open(kind); feedback.selection() }
                            .accessibilityIdentifier("chooseLab-\(kind.rawValue)")
                    }
                } label: {
                    Image(systemName: "square.grid.2x2").frame(width: 48, height: 48).glassEffect(.regular.interactive(), in: .circle)
                }.accessibilityLabel("Choose instrument").accessibilityIdentifier("labMenu")
            }
            if let lesson = session.lesson {
                DegreePanel(lesson.title) {
                    Text(lesson.concept).font(.subheadline).foregroundStyle(HarmonicTheme.muted)
                    Text(lesson.steps.first ?? lesson.creationTask).font(.subheadline)
                    NavigationLink("Read the investigation") { LessonDetailView(lesson: lesson, session: session) }.foregroundStyle(HarmonicTheme.cyan)
                }
            }
            HeroInstrument(state: session.state, evaluation: session.evaluation, motion: motion)
                .frame(maxWidth: .infinity).accessibilityIdentifier("instrumentHero")
            if dynamicType.isAccessibilitySize, let primary = session.evaluation.readouts.first {
                Text("\(primary.title): \(harmonicNumber(primary.value)) \(primary.unit)").font(.title2).foregroundStyle(HarmonicTheme.cyan).accessibilityIdentifier("accessibleHeroReadout")
            }
            DegreePanel("Live model") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicType.isAccessibilitySize ? 180 : 120))], spacing: 18) {
                    ForEach(session.evaluation.readouts, id: \.id) { item in
                        InstrumentMetricReadout(item.title.uppercased(), value: harmonicNumber(item.value), unit: item.unit,
                                                color: item.id == session.evaluation.readouts.first?.id ? HarmonicTheme.cyan : HarmonicTheme.amber)
                            .accessibilityIdentifier("readout-\(item.id)")
                    }
                }
            }
            DegreePanel("Controls") {
                ForEach(definition.parameters, id: \.id) { parameter in
                    ParameterControl(parameter: parameter, value: session.state.values[parameter.id] ?? parameter.defaultValue,
                        change: { let before = session.state.values[parameter.id]; session.set(parameter.id, $0); if session.state.values[parameter.id] != before { feedback.acceptedChange(upward: $0 > (before ?? $0)) } },
                        edit: { editorValue = String(session.state.values[parameter.id] ?? parameter.defaultValue); editorParameter = parameter })
                }
                Button { audio.stop(); session.reset(); feedback.selection() } label: { Label("Restore starting values", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(DegreeAction()).accessibilityIdentifier("resetLab")
            }
            if [.timbre, .composition].contains(session.state.kind) { harmonics }
            if [.scales, .harmony, .voiceLeading, .composition].contains(session.state.kind) { piano }
            if session.state.kind == .composition { score }
            DegreePanel("Model trace") { ModelWavePlot(evaluation: session.evaluation) }
            if !session.evaluation.spectrum.isEmpty { DegreePanel("Frequency components") { SpectrumPlot(bins: session.evaluation.spectrum, caption: session.evaluation.spectrumCaption) } }
            DegreePanel("Why it works") {
                Text(session.evaluation.equation).font(.system(.body, design: .monospaced)).foregroundStyle(HarmonicTheme.cyan).textSelection(.enabled)
                Text(session.evaluation.explanation).font(.subheadline)
            }
            DegreePanel("Prediction and evidence") {
                Text("Commit a prediction for a changed setting, then compare it with the model. Your answer and the starting state are saved together.").font(.subheadline).foregroundStyle(HarmonicTheme.muted)
                HStack {
                    Button { session.beginPrediction(); prediction = true } label: { Label("Predict", systemImage: "questionmark") }
                        .buttonStyle(DegreeAction(accent: HarmonicTheme.amber)).accessibilityIdentifier("predictButton")
                    Button { saving = true } label: { Label("Save run", systemImage: "square.and.arrow.down") }
                        .buttonStyle(DegreeAction()).accessibilityIdentifier("saveRunButton")
                }
                Text(session.status).font(.caption).foregroundStyle(HarmonicTheme.muted).accessibilityIdentifier("sessionStatus")
            }
            if let lesson = session.lesson {
                DegreePanel("Make the connection") {
                    Text(lesson.mathTask).font(.subheadline)
                    Text(lesson.musicTask).font(.subheadline).foregroundStyle(HarmonicTheme.amber)
                    Text(lesson.creationTask).font(.subheadline)
                }
                SourceLinks(ids: lesson.sourceIDs)
            }
            if [.string, .room].contains(session.state.kind) && LabModel.audio(session.state).voices.isEmpty {
                Text("Below 20 Hz: visual model only at this setting.").font(.caption).foregroundStyle(HarmonicTheme.amber)
            }
            DegreePanel("Model boundaries") { Text(session.evaluation.limitation).font(.caption).foregroundStyle(HarmonicTheme.muted) }
        }.navigationTitle("Studio").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 10) {
                    Button {
                        if audio.isPlaybackRequested { audio.stop() }
                        else if session.soundEnabled { audio.play(configuration: LabModel.audio(session.state), duration: 12) }
                        feedback.selection()
                    } label: { Label(audio.isPlaybackRequested ? (audio.isStarting ? "Starting · Stop" : "Stop sound") : "Audition · 12 s", systemImage: audio.isPlaybackRequested ? "stop.fill" : "play.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(DegreeAction(accent: HarmonicTheme.amber)).accessibilityIdentifier("audioTransport")
                        .disabled(!session.soundEnabled)
                    Button { saving = true } label: { Image(systemName: "square.and.arrow.down").frame(width: 44) }
                        .buttonStyle(DegreeAction()).accessibilityLabel("Save experiment").accessibilityIdentifier("dockSaveRun")
                }.padding(.horizontal, 18).padding(.vertical, 8)
            }
            .sheet(isPresented: $prediction) { PredictionView(session: session, feedback: feedback) }
            .sheet(isPresented: $saving) { SaveRunView(session: session) }
            .sheet(item: $editorParameter) { parameter in
                NavigationStack {
                    Form {
                        Section(parameter.title) {
                            TextField("Value in \(parameter.unit)", text: $editorValue).keyboardType(.numbersAndPunctuation).accessibilityIdentifier("parameterText")
                            Text("Allowed \(harmonicNumber(parameter.range.lowerBound))–\(harmonicNumber(parameter.range.upperBound)) \(parameter.unit)").font(.caption)
                        }
                        Button("Apply value") {
                            if let value = Double(editorValue.replacingOccurrences(of: ",", with: ".")), value.isFinite {
                                session.set(parameter.id, value); feedback.acceptedChange(); editorParameter = nil
                            }
                        }.accessibilityIdentifier("applyParameter")
                    }.navigationTitle("Exact value")
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editorParameter = nil } } }
                }
            }
    }
    private var harmonics: some View {
        DegreePanel("Build the voice") {
            Text("Partial amplitudes · actual synthesis omits components beyond its Nyquist guard.").font(.caption).foregroundStyle(HarmonicTheme.muted)
            ForEach(0..<8, id: \.self) { index in
                HStack {
                    Text("H\(index + 1)").font(.system(.caption, design: .monospaced)).frame(width: 30)
                    Slider(value: Binding(get: { session.state.harmonics[index] }, set: { session.setHarmonic(index, $0) }), in: 0...1)
                        .tint(index == 0 ? HarmonicTheme.cyan : HarmonicTheme.violet)
                        .accessibilityLabel("Harmonic \(index + 1) amplitude").accessibilityIdentifier("harmonic-\(index)")
                        .instrumentControlOwnsTouches(identifier: "harmonic-\(index)")
                    Text(harmonicNumber(session.state.harmonics[index])).font(.system(.caption, design: .monospaced)).frame(width: 42)
                }.frame(minHeight: 44)
            }
        }
    }
    private var piano: some View {
        DegreePanel("Playable keys") {
            Text("Select up to four keys to compare a voicing. Each tap auditions the selected pitches; sound can be disabled in settings.").font(.caption).foregroundStyle(HarmonicTheme.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 8) {
                ForEach(60...71, id: \.self) { midi in
                    Button {
                        let before = session.state.notes
                        session.toggleNote(midi)
                        guard session.state.notes != before else { feedback.boundary(); return }
                        feedback.selection()
                        if session.soundEnabled && !session.state.notes.isEmpty {
                            let voices = session.state.notes.prefix(4).map { AudioVoice(frequency: 440 * pow(2, Double($0 - 69) / 12), amplitudes: [0.8, 0.2]) }
                            audio.play(configuration: ToneConfiguration(voices: Array(voices)), duration: 2)
                        } else { audio.stop() }
                    } label: {
                        Text(noteLabel(midi)).font(.system(.caption, design: .monospaced, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(session.state.notes.contains(midi) ? InstrumentPalette.canvas : HarmonicTheme.ink)
                            .background(session.state.notes.contains(midi) ? HarmonicTheme.cyan : InstrumentPalette.content, in: .rect(cornerRadius: 10))
                    }.buttonStyle(.plain).accessibilityLabel("Key \(noteLabel(midi))")
                        .accessibilityValue(session.state.notes.contains(midi) ? "Selected" : "Not selected")
                        .accessibilityIdentifier("piano-\(midi)")
                }
            }
            Text("Selected: \(session.state.notes.sorted().map(noteLabel).joined(separator: " · "))").font(.caption).foregroundStyle(HarmonicTheme.cyan)
        }
    }
    private var score: some View {
        DegreePanel("Your sixteen-step phrase") {
            Text("One 4/4 bar · each slot is a sixteenth note. Tap a slot to edit its pitch or rest.").font(.caption).foregroundStyle(HarmonicTheme.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 8) {
                ForEach(0..<16, id: \.self) { index in
                    Menu {
                        Button("Rest") { session.setStep(index, -1) }
                        ForEach(0...8, id: \.self) { octave in
                            Menu("Octave \(octave)") {
                                ForEach(max(21, (octave + 1) * 12)...min(108, (octave + 2) * 12 - 1), id: \.self) { midi in
                                    Button(noteLabel(midi)) { session.setStep(index, midi); feedback.acceptedChange() }
                                        .accessibilityIdentifier("scorePitch-\(midi)")
                                }
                            }.accessibilityIdentifier("scoreOctave-\(octave)")
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Text(String(index + 1)).font(.system(.caption2, design: .monospaced)).foregroundStyle(HarmonicTheme.muted)
                            Text(session.state.steps[index] < 0 ? "—" : noteLabel(session.state.steps[index])).font(.system(.body, design: .monospaced)).foregroundStyle(HarmonicTheme.cyan)
                        }.frame(maxWidth: .infinity, minHeight: 54).background(InstrumentPalette.content, in: .rect(cornerRadius: 10))
                    }.accessibilityLabel("Score step \(index + 1)").accessibilityValue(session.state.steps[index] < 0 ? "Rest" : noteLabel(session.state.steps[index])).accessibilityIdentifier("score-\(index)")
                }
            }
            Button("Transpose phrase up one semitone") {
                for index in 0..<16 where session.state.steps[index] >= 0 { session.setStep(index, session.state.steps[index] + 1) }
                feedback.acceptedChange()
            }.buttonStyle(DegreeAction()).accessibilityIdentifier("transposePhrase")
            Button("Transpose phrase down one semitone") {
                for index in 0..<16 where session.state.steps[index] >= 0 { session.setStep(index, session.state.steps[index] - 1) }
                feedback.acceptedChange()
            }.buttonStyle(DegreeAction()).accessibilityIdentifier("transposePhraseDown")
        }
    }
}

extension LabParameter: @retroactive Identifiable {}

struct ParameterControl: View {
    var parameter: LabParameter
    var value: Double
    var change: (Double) -> Void
    var edit: () -> Void
    private var fineStep: Double { parameter.step > 0 ? parameter.step : (parameter.unit == "Hz" ? 1 : (parameter.range.upperBound - parameter.range.lowerBound) / 1000) }
    private var sliderRange: ClosedRange<Double> { parameter.logarithmic ? log10(parameter.range.lowerBound)...log10(parameter.range.upperBound) : parameter.range }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(parameter.title).font(.subheadline)
                Spacer()
                Button { edit() } label: { Text("\(harmonicNumber(value)) \(parameter.unit)").font(.system(.subheadline, design: .monospaced)).foregroundStyle(HarmonicTheme.cyan).frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel("Edit \(parameter.title) exactly").accessibilityValue("\(harmonicNumber(value)) \(parameter.unit)").accessibilityIdentifier("edit-\(parameter.id)")
            }
            Slider(value: Binding(get: { parameter.logarithmic ? log10(max(parameter.range.lowerBound, value)) : value }, set: { change(parameter.logarithmic ? pow(10, $0) : $0) }), in: sliderRange)
                .tint(HarmonicTheme.cyan).accessibilityLabel(parameter.title).accessibilityValue("\(harmonicNumber(value)) \(parameter.unit)")
                .accessibilityIdentifier("param-\(parameter.id)").instrumentControlOwnsTouches(identifier: "param-\(parameter.id)")
            Stepper("Fine adjustment", onIncrement: { change(min(parameter.range.upperBound, value + fineStep)) }, onDecrement: { change(max(parameter.range.lowerBound, value - fineStep)) })
                .font(.caption).accessibilityLabel("\(parameter.title), fine adjustment").accessibilityValue("\(harmonicNumber(value)) \(parameter.unit)").accessibilityIdentifier("stepper-\(parameter.id)")
                .instrumentControlOwnsTouches(identifier: "stepper-\(parameter.id)")
        }
    }
}

func noteLabel(_ midi: Int) -> String {
    let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    return "\(names[(midi % 12 + 12) % 12])\(midi / 12 - 1)"
}

struct PredictionView: View {
    var session: DegreeSession
    var feedback: HarmonicFeedback
    @Environment(\.dismiss) private var dismiss
    @State private var answer = ""
    @State private var reasoning = ""
    @State private var question: PredictionTask?
    var body: some View {
        NavigationStack {
            DegreeScroll {
                DegreeHeader(eyebrow: "Commit before checking", title: "Make a prediction", subtitle: "This numerical check records one specific demonstration. The lesson's broader musical and formal tasks remain in your investigation.")
                if let question {
                    DegreePanel("Changed-setting challenge") {
                        Text(question.prompt).font(.title3).accessibilityIdentifier("predictionPrompt")
                        TextField("Your prediction (\(question.unit))", text: $answer).keyboardType(.numbersAndPunctuation).textFieldStyle(.roundedBorder).accessibilityIdentifier("predictionAnswer")
                        TextField("Explain your reasoning", text: $reasoning, axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder).accessibilityIdentifier("predictionReasoning")
                        Button("Commit and check") {
                            let matched = session.checkPrediction(answer, note: reasoning)
                            if matched { feedback.success() }
                        }.buttonStyle(DegreeAction(accent: HarmonicTheme.amber)).accessibilityIdentifier("checkPrediction").disabled(session.latestPrediction != nil)
                    }
                }
                if let evidence = session.latestPrediction {
                    DegreePanel(evidence.matched ? "Prediction matched" : "Compare and revise") {
                        Text("Your prediction: \(harmonicNumber(evidence.entered)) \(evidence.unit)")
                        Text("Model result: \(harmonicNumber(evidence.expected)) \(evidence.unit)").foregroundStyle(HarmonicTheme.cyan).accessibilityIdentifier("predictionResult")
                        Text("Tolerance: ±\(harmonicNumber(evidence.tolerance)) \(evidence.unit)").font(.caption)
                        Text(session.isDurable ? "The question, answer, configuration and reasoning are saved in your notebook." : "This prediction is held in this session. Export it before closing the app.").font(.caption).foregroundStyle(HarmonicTheme.muted)
                    }
                }
                Text(session.status).font(.caption).foregroundStyle(HarmonicTheme.muted)
            }.navigationTitle("Prediction").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("predictionDone") } }
                .onAppear { question = session.pendingPrediction }
        }
    }
}

struct SaveRunView: View {
    var session: DegreeSession
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var note = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Your investigation") {
                    TextField("Title", text: $title).accessibilityIdentifier("runTitle")
                    TextField("Prediction, observations, derivation and musical intention", text: $note, axis: .vertical).lineLimit(5...12).accessibilityIdentifier("runNote")
                    Text("The app also saves the exact controls, partials, score, selected keys, equation, model limits and lesson sources.").font(.caption)
                }
                Button(session.isDurable ? "Save to notebook" : "Keep in this session") { session.saveExperiment(title: title, note: note); dismiss() }.accessibilityIdentifier("confirmSaveRun")
            }.navigationTitle("Save investigation")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
