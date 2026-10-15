import Foundation
import Observation
import HarmonicCore

struct PredictionEvidence: Codable, Equatable {
    var prompt: String
    var entered: Double
    var expected: Double
    var unit: String
    var tolerance: Double
    var matched: Bool
}

struct NotebookEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var title: String
    var kind: String
    var state: LabState
    var lessonID: String?
    var projectID: String?
    var note: String
    var evidence: PredictionEvidence?
    var equation: String
    var modelLimit: String
    var sourceIDs: [String]
    var modelVersion = 1
    var reviewedAt: Date?
    var attachments: [NotebookEntry] = []

    var markdown: String {
        let input = state.values.sorted { $0.key < $1.key }.map { "- \($0.key): \($0.value)" }.joined(separator: "\n")
        let sources = sourceIDs.compactMap { id in DegreeCurriculum.sources.first { $0.id == id } }.map { "- \($0.title): \($0.url)" }.joined(separator: "\n")
        let prediction = evidence.map { "Question: \($0.prompt)\nPrediction: \($0.entered) \($0.unit)\nModel result: \($0.expected) \($0.unit)\nTolerance: \($0.tolerance)\nOutcome: \($0.matched ? "Matched this prediction" : "Revise the reasoning")" } ?? "Saved experiment; no checked prediction."
        return "# \(title)\n\nPrinciples · \(date.formatted()) · Model v\(modelVersion)\n\n## Configuration\n\n\(input)\n\nHarmonics: \(state.harmonics)\nScore MIDI/rest: \(state.steps)\nSelected keys: \(state.notes)\n\n## Evidence\n\n\(prediction)\n\n## Reasoning\n\n\(note)\n\n## Equation\n\n\(equation)\n\n## Model limits\n\n\(modelLimit)\n\n## Sources\n\n\(sources)\n\n" + attachments.map { "## Attached investigation\n\n" + $0.markdown }.joined(separator: "\n\n")
    }
}

struct ProjectDraft: Identifiable, Codable, Equatable {
    var id: String
    var statement = ""
    var mathReasoning = ""
    var musicalReasoning = ""
    var checkedCriteria: Set<Int> = []
    var evidenceIDs: Set<UUID> = []
    var submittedAt: Date?
}

@Observable @MainActor
final class DegreeSession {
    private struct Archive: Codable {
        var version = 1
        var state = LabState(kind: .tone)
        var selectedLessonID: String?
        var entries: [NotebookEntry] = []
        var projects: [String: ProjectDraft] = [:]
        var soundEnabled = true
        var hapticsEnabled = true
        var motionEnabled = true
    }
    private var archive = Archive()
    private let url: URL
    private var canPersist = true
    private(set) var isDurable = true
    private(set) var persistenceWarning: String?
    var error: String?
    var status = "Your instrument is ready."
    var tab = 0
    var evaluation: LabEvaluation
    var pendingPrediction: PredictionTask?
    var predictionState: LabState?
    var predictionLessonID: String?
    var reviewingEntryID: UUID?
    var latestPrediction: PredictionEvidence?

    var state: LabState { archive.state }
    var selectedLessonID: String? { archive.selectedLessonID }
    var lesson: DegreeLesson? { DegreeCurriculum.lessons.first { $0.id == selectedLessonID } }
    var entries: [NotebookEntry] { archive.entries }
    var soundEnabled: Bool { get { archive.soundEnabled } set { archive.soundEnabled = newValue; persist() } }
    var hapticsEnabled: Bool { get { archive.hapticsEnabled } set { archive.hapticsEnabled = newValue; persist() } }
    var motionEnabled: Bool { get { archive.motionEnabled } set { archive.motionEnabled = newValue; persist() } }
    var matchedPredictions: Int { entries.filter { $0.evidence?.matched == true }.count }
    var investigatedLessons: Set<String> { Set(entries.compactMap(\.lessonID)) }
    var reviews: [NotebookEntry] { entries.filter { $0.evidence?.matched == true && $0.reviewedAt == nil } }

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "Harmonic/notebook-v1.json")
        evaluation = LabModel.evaluate(LabState(kind: .tone))
        if FileManager.default.fileExists(atPath: self.url.path) {
            do {
                let loaded = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: self.url))
                guard loaded.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
                archive = loaded
                archive.state = archive.state.normalized()
                evaluation = LabModel.evaluate(archive.state)
            } catch {
                canPersist = false
                isDurable = false
                persistenceWarning = "The existing notebook file is preserved. New work is in memory only; export investigations before closing Principles."
                self.error = "The existing notebook could not be read. Its file is preserved. New work remains in this session."
            }
        }
    }

    func open(_ kind: LabKind) {
        reviewingEntryID = nil
        archive.state = LabState(kind: kind)
        archive.selectedLessonID = nil
        recompute(); tab = 1
    }
    func open(_ lesson: DegreeLesson) {
        reviewingEntryID = nil
        archive.state = LabState(kind: LabKind(rawValue: lesson.labID) ?? .tone)
        for (key, value) in lesson.startingValues { archive.state.set(id: key, value: value) }
        archive.selectedLessonID = lesson.id
        recompute(); tab = 1
    }
    func set(_ key: String, _ value: Double) {
        archive.state.set(id: key, value: value); recompute()
    }
    func setHarmonic(_ index: Int, _ value: Double) {
        guard archive.state.harmonics.indices.contains(index) else { return }
        archive.state.harmonics[index] = min(1, max(0, value)); recompute()
    }
    func setStep(_ index: Int, _ midi: Int) {
        guard archive.state.steps.indices.contains(index) else { return }
        archive.state.steps[index] = midi; recompute()
    }
    func toggleNote(_ midi: Int) {
        if archive.state.notes.contains(midi) { archive.state.notes.removeAll { $0 == midi } }
        else {
            guard archive.state.notes.count < 4 else { status = "Four keys can sound together. Release a selected key before adding another."; return }
            archive.state.notes.append(midi)
        }
        recompute()
    }
    func reset() {
        if let lesson { open(lesson) } else { open(state.kind) }
        status = "Restored the starting experiment."
    }
    func beginPrediction() {
        pendingPrediction = evaluation.prediction
        predictionState = state
        predictionLessonID = selectedLessonID
        latestPrediction = nil
    }
    @discardableResult
    func checkPrediction(_ text: String, note: String) -> Bool {
        guard let question = pendingPrediction, let frozen = predictionState,
              let value = Double(text.replacingOccurrences(of: ",", with: ".")), value.isFinite else {
            status = "Enter a finite numerical prediction first."; return false
        }
        let evidence = PredictionEvidence(prompt: question.prompt, entered: value, expected: question.answer,
                                          unit: question.unit, tolerance: question.tolerance,
                                          matched: abs(value - question.answer) <= question.tolerance)
        latestPrediction = evidence
        if evidence.matched, let reviewingEntryID { markReviewed(reviewingEntryID); self.reviewingEntryID = nil }
        let evaluated = LabModel.evaluate(frozen)
        archive.entries.insert(NotebookEntry(title: "Prediction · \(LabCatalog.definition(for: frozen.kind).title)",
            kind: "prediction", state: frozen, lessonID: predictionLessonID, note: note, evidence: evidence,
            equation: evaluated.equation, modelLimit: evaluated.limitation,
            sourceIDs: DegreeCurriculum.lessons.first { $0.id == predictionLessonID }?.sourceIDs ?? Array(Set(DegreeCurriculum.lessons.filter { $0.labID == frozen.kind.rawValue }.flatMap(\.sourceIDs))).sorted()), at: 0)
        pendingPrediction = nil
        let persisted = persist()
        let result = evidence.matched ? "This prediction matched. Explain why, then try another setting." : "Compare your prediction with the model and revise the reasoning."
        status = persisted ? result : result + " This prediction is in memory only; export it before closing Principles."
        return evidence.matched
    }
    func saveExperiment(title: String, note: String) {
        archive.entries.insert(NotebookEntry(title: title.isEmpty ? LabCatalog.definition(for: state.kind).title : title,
            kind: "experiment", state: state, lessonID: selectedLessonID, note: note, equation: evaluation.equation,
            modelLimit: evaluation.limitation, sourceIDs: lesson?.sourceIDs ?? Array(Set(DegreeCurriculum.lessons.filter { $0.labID == state.kind.rawValue }.flatMap(\.sourceIDs))).sorted()), at: 0)
        status = persist() ? "Saved the configuration, model and your reasoning." : "The configuration, model and reasoning are in memory only. Export this investigation before closing Principles."
    }
    func restore(_ entry: NotebookEntry) {
        reviewingEntryID = nil
        archive.state = entry.state.normalized(); archive.selectedLessonID = entry.lessonID
        recompute(); tab = 1; status = "Restored the saved experiment. The original record is unchanged."
    }
    func beginReview(_ entry: NotebookEntry) { restore(entry); reviewingEntryID = entry.id }
    func delete(_ id: UUID) {
        archive.entries.removeAll { $0.id == id }
        // Draft selections refer to the live notebook. Submitted attachment snapshots stay intact.
        for projectID in Array(archive.projects.keys) {
            archive.projects[projectID]?.evidenceIDs.remove(id)
        }
        persist()
    }
    func markReviewed(_ id: UUID) {
        guard let index = archive.entries.firstIndex(where: { $0.id == id }) else { return }
        archive.entries[index].reviewedAt = Date(); persist()
    }
    func project(_ id: String) -> ProjectDraft { archive.projects[id] ?? ProjectDraft(id: id) }
    func updateProject(_ draft: ProjectDraft) {
        var valid = draft
        // A view may hold a stale draft across tab changes. Only live investigations can be attached.
        let eligibleIDs = Set(entries.filter { $0.projectID == nil }.map(\.id))
        valid.evidenceIDs.formIntersection(eligibleIDs)
        archive.projects[valid.id] = valid
        persist()
    }
    func submitProject(_ project: DegreeProject) -> Bool {
        var draft = self.project(project.id)
        guard !draft.statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              draft.mathReasoning.count >= 20, draft.musicalReasoning.count >= 20,
              draft.checkedCriteria.count == project.acceptanceCriteria.count,
              !draft.evidenceIDs.isEmpty, draft.evidenceIDs.isSubset(of: Set(entries.map(\.id))) else { status = "Add your design statement, both explanations, saved evidence and criterion checks."; return false }
        draft.submittedAt = Date(); updateProject(draft)
        let attached = entries.filter { draft.evidenceIDs.contains($0.id) }
        archive.entries.insert(NotebookEntry(title: project.title, kind: "project submission", state: state,
            lessonID: selectedLessonID, projectID: project.id,
            note: "Design: \(draft.statement)\n\nMath/physics: \(draft.mathReasoning)\n\nMusic: \(draft.musicalReasoning)\n\nSelf-reviewed criteria: \(draft.checkedCriteria.sorted())\nEvidence: \(draft.evidenceIDs.map(\.uuidString).sorted().joined(separator: ", "))\nSubmission saved for review; no automatic artistic or mastery grade.",
            equation: evaluation.equation, modelLimit: project.modelLimit, sourceIDs: project.sourceIDs, attachments: attached), at: 0)
        status = persist() ? "Project submitted to your notebook for review." : "Project recorded in this session for review. It is in memory only; export it before closing Principles."
        return true
    }
    private func recompute() {
        archive.state = archive.state.normalized(); evaluation = LabModel.evaluate(archive.state)
        pendingPrediction = nil; predictionState = nil; latestPrediction = nil; persist()
    }
    @discardableResult
    private func persist() -> Bool {
        guard canPersist else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(archive).write(to: url, options: .atomic)
            isDurable = true
            persistenceWarning = nil
            error = nil
            return true
        } catch {
            isDurable = false
            persistenceWarning = "Notebook save failed. Work is in memory only; export investigations before closing Principles."
            self.error = "Notebook save failed. Work remains available in this session: \(error.localizedDescription)"
            return false
        }
    }
}
