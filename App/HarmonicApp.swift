import SwiftUI
import HarmonicCore

@main
struct HarmonicApp: App {
    @State private var session: DegreeSession
    @State private var audio = HarmonicAudioEngine()
    @State private var feedback = HarmonicFeedback()
    @State private var motion = HarmonicMotion()
    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--qa-id"), arguments.indices.contains(index + 1) {
            let identifier = String(arguments[index + 1].filter { $0.isLetter || $0.isNumber || $0 == "-" }.prefix(50))
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let url = root.appending(path: "Harmonic/QA/\(identifier)/notebook.json")
            if arguments.contains("--qa-reset") { try? FileManager.default.removeItem(at: url) }
            let session = DegreeSession(url: url)
            if let labIndex = arguments.firstIndex(of: "--qa-lab"), arguments.indices.contains(labIndex + 1),
               let kind = LabKind(rawValue: arguments[labIndex + 1]), arguments.contains("--qa-reset") { session.open(kind) }
            else { session.tab = 1 }
            _session = State(initialValue: session)
        } else { _session = State(initialValue: DegreeSession()) }
    }
    var body: some Scene {
        WindowGroup {
            HarmonicRootView(session: session, audio: audio, feedback: feedback, motion: motion)
                .preferredColorScheme(.dark)
        }
    }
}
