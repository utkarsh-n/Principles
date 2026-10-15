import SwiftUI
import HarmonicCore

struct HarmonicRootView: View {
    @Bindable var session: DegreeSession
    var audio: HarmonicAudioEngine
    var feedback: HarmonicFeedback
    var motion: HarmonicMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settings = false

    var body: some View {
        TabView(selection: $session.tab) {
            Tab("Map", systemImage: "point.3.connected.trianglepath.dotted", value: 0) {
                NavigationStack { DegreeMapView(session: session).toolbar { ToolbarItem(placement: .topBarTrailing) { settingsControl } } }
            }
            Tab("Studio", systemImage: "waveform", value: 1) {
                NavigationStack { StudioView(session: session, audio: audio, feedback: feedback, motion: motion).toolbar { ToolbarItem(placement: .topBarTrailing) { settingsControl } } }
            }
            Tab("Projects", systemImage: "hammer", value: 2) {
                NavigationStack { DegreeProjectsView(session: session).toolbar { ToolbarItem(placement: .topBarTrailing) { settingsControl } } }
            }
            Tab("Notebook", systemImage: "book.closed", value: 3) {
                NavigationStack { NotebookView(session: session).toolbar { ToolbarItem(placement: .topBarTrailing) { settingsControl } } }
            }
            Tab("Review", systemImage: "arrow.clockwise", value: 4) {
                NavigationStack { DegreeReviewView(session: session).toolbar { ToolbarItem(placement: .topBarTrailing) { settingsControl } } }
            }
        }.tint(HarmonicTheme.cyan)
            .safeAreaInset(edge: .top) {
                if let warning = session.persistenceWarning {
                    Label(warning, systemImage: "externaldrive.badge.exclamationmark")
                        .font(.caption).foregroundStyle(HarmonicTheme.amber)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(InstrumentPalette.content).accessibilityIdentifier("persistenceWarning")
                }
            }
            .sheet(isPresented: $settings) { SettingsView(session: session, audio: audio, feedback: feedback, motion: motion) }
            .task {
                feedback.enabled = session.hapticsEnabled
                updateMotion()
            }
            .onChange(of: session.state) { old, new in
                if old.kind != new.kind { audio.stop() }
                else if audio.isPlaybackRequested && (old.values != new.values || old.harmonics != new.harmonics || old.steps != new.steps) { _ = audio.update(configuration: LabModel.audio(new)) }
            }
            .onChange(of: session.tab) { _, tab in if tab != 1 { audio.stop() } }
            .onChange(of: session.selectedLessonID) { audio.stop() }
            .onChange(of: session.soundEnabled) { if !session.soundEnabled { audio.stop() } }
            .onChange(of: session.hapticsEnabled) { feedback.enabled = session.hapticsEnabled }
            .onChange(of: session.motionEnabled) { updateMotion() }
            .onChange(of: reduceMotion) { updateMotion() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { audio.suspend(); motion.stop() }
                else { updateMotion() }
            }
            .alert("Notebook", isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })) {
                Button("OK") { session.error = nil }
            } message: { Text(session.error ?? "") }
    }
    private var settingsControl: some View {
        Button("Settings", systemImage: "slider.horizontal.3") { settings = true }.accessibilityIdentifier("settingsButton")
    }
    private func updateMotion() {
        if session.motionEnabled && !reduceMotion && scenePhase == .active { motion.start() }
        else { motion.stop() }
    }
}

struct SettingsView: View {
    @Bindable var session: DegreeSession
    var audio: HarmonicAudioEngine
    var feedback: HarmonicFeedback
    var motion: HarmonicMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        NavigationStack {
            Form {
                Section("Sensory channels") {
                    Toggle("Sound auditions", isOn: $session.soundEnabled).accessibilityIdentifier("soundToggle")
                    Toggle("Accepted-change haptics", isOn: $session.hapticsEnabled).accessibilityIdentifier("hapticsToggle")
                    Toggle("Motion lighting", isOn: $session.motionEnabled).accessibilityIdentifier("motionToggle")
                    Text("Motion changes the instrument's light. Quantities, sound, controls and saved experiments remain anchored.").font(.caption)
                }
                Section("Output") {
                    LabeledContent("Route", value: audio.outputRouteLabel)
                    Text(audio.telemetry.status).accessibilityIdentifier("audioStatus")
                    #if DEBUG
                    Text(audio.debugSummary).font(.system(.caption2, design: .monospaced)).accessibilityIdentifier("renderEvidence")
                    #endif
                    LabeledContent("Requested revision", value: String(audio.telemetry.requestedRevision))
                    LabeledContent("Rendered revision", value: String(audio.telemetry.appliedRevision)).accessibilityIdentifier("appliedRevision")
                    LabeledContent("Sample rate", value: "\(harmonicNumber(audio.telemetry.sampleRate)) Hz")
                    LabeledContent("Digital peak", value: harmonicNumber(audio.telemetry.peak)).accessibilityIdentifier("audioPeak")
                    Text("Digital amplitude is not sound pressure. Render acknowledgement does not measure acoustic or Bluetooth latency.").font(.caption)
                }
                Section("Motion") {
                    Text(motion.status).accessibilityIdentifier("motionStatus")
                    LabeledContent("Live samples", value: String(motion.sampleCount)).accessibilityIdentifier("motionCount")
                    Text("x \(harmonicNumber(motion.x)) · y \(harmonicNumber(motion.y))").accessibilityIdentifier("motionSample")
                }
                #if DEBUG
                Section("Hardware evidence") {
                    Text("reduceMotion=\(reduceMotion)").font(.caption).accessibilityIdentifier("reduceMotionEvidence")
                    Text("samples=\(motion.sampleCount); active=\(motion.isActive)").font(.caption).accessibilityIdentifier("sensorEvidence")
                    Text("events=\(feedback.emittedEventCount); core=\(feedback.usedCoreHaptics); last=\(feedback.lastEvent)").font(.caption).accessibilityIdentifier("tactileEvidence")
                }
                #endif
                Section("Tactile output") {
                    Text(feedback.status).accessibilityIdentifier("hapticStatus")
                    LabeledContent("Submitted cues", value: String(feedback.emittedEventCount)).accessibilityIdentifier("hapticCount")
                    LabeledContent("Last cue", value: feedback.lastEvent)
                    Text("A submitted cue is device-service evidence. Felt intensity and timing require hands-on assessment.").font(.caption)
                }
                Section("Evidence") {
                    Text("Matched predictions document specific tasks. Projects retain your evidence and self-review; the app does not automatically grade artistic quality.")
                    Link("Curriculum references", destination: URL(string: "https://ocw.mit.edu/courses/21m-051-fundamentals-of-music-spring-2007/pages/syllabus/")!)
                }
            }.navigationTitle("Instrument settings")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("settingsDone") } }
        }
    }
}
