import XCTest
@testable import Harmonic
import HarmonicCore

@MainActor
final class DegreeSessionTests: XCTestCase {
    private func file() -> URL { FileManager.default.temporaryDirectory.appending(path: "HarmonicTests/\(UUID().uuidString)/notebook.json") }

    func testSaveRestorePreservesArtifactAndEquation() {
        let url = file(), session = DegreeSession(url: url)
        session.open(.composition)
        session.set("bpm", 120)
        session.setHarmonic(3, 0.8)
        session.setStep(0, 72)
        session.toggleNote(64)
        session.saveExperiment(title: "A mathematical phrase", note: "Quarter-note repetition creates a deliberate rhythmic constraint.")
        XCTAssertTrue(session.isDurable)
        XCTAssertNil(session.persistenceWarning)
        let original = session.state
        XCTAssertEqual(session.entries.count, 1)
        let loaded = DegreeSession(url: url)
        XCTAssertEqual(loaded.state, original)
        XCTAssertEqual(loaded.entries.first?.state, original)
        loaded.open(.tone)
        loaded.restore(loaded.entries[0])
        XCTAssertEqual(loaded.state, original)
        XCTAssertTrue(loaded.entries[0].markdown.contains("72"))
        XCTAssertTrue(loaded.entries[0].markdown.contains("Quarter-note repetition"))
    }

    func testPredictionUsesCapturedTaskAndKeepsWrongEvidence() {
        let session = DegreeSession(url: file())
        session.open(.tone)
        session.set("frequency", 440)
        session.beginPrediction()
        let answer = session.pendingPrediction!.answer
        XCTAssertTrue(session.checkPrediction(String(answer), note: "Frequency doubled, so period halves."))
        XCTAssertEqual(session.entries.first?.evidence?.expected, answer)
        XCTAssertEqual(session.entries.first?.state.values["frequency"], 440)
        session.beginPrediction()
        XCTAssertFalse(session.checkPrediction("-100", note: "An intentionally incorrect hypothesis."))
        XCTAssertEqual(session.entries.count, 2)
        XCTAssertEqual(session.matchedPredictions, 1)
        XCTAssertFalse(session.entries[0].evidence!.matched)
    }

    func testInvalidPredictionDoesNotBecomeEvidence() {
        let session = DegreeSession(url: file())
        session.beginPrediction()
        for invalid in ["", "nan", "inf", "word"] {
            XCTAssertFalse(session.checkPrediction(invalid, note: ""))
            XCTAssertTrue(session.entries.isEmpty)
        }
        session.set("frequency", 330)
        XCTAssertFalse(session.checkPrediction("1", note: "Superseded task"))
        XCTAssertTrue(session.entries.isEmpty)
    }

    func testUnreadableNotebookIsPreserved() throws {
        let url = file()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bad = Data("{an unreadable saved notebook}".utf8)
        try bad.write(to: url)
        let session = DegreeSession(url: url)
        XCTAssertNotNil(session.error)
        XCTAssertFalse(session.isDurable)
        XCTAssertNotNil(session.persistenceWarning)
        session.error = nil
        session.saveExperiment(title: "Preserved in memory", note: "")
        XCTAssertTrue(session.status.contains("memory only"))
        XCTAssertNotNil(session.persistenceWarning, "Dismissing the alert must not hide the persistence state")
        session.beginPrediction()
        XCTAssertTrue(session.checkPrediction(String(session.pendingPrediction!.answer), note: "A prediction preserved in this session."))
        XCTAssertTrue(session.status.contains("memory only"))
        let project = DegreeCurriculum.projects[0]
        var draft = session.project(project.id)
        draft.statement = "A session-only project"
        draft.mathReasoning = "The recorded equation determines the modeled frequency."
        draft.musicalReasoning = "The selected timbre supports the intended musical contrast."
        draft.checkedCriteria = Set(project.acceptanceCriteria.indices)
        draft.evidenceIDs = [session.entries[0].id]
        session.updateProject(draft)
        XCTAssertTrue(session.submitProject(project))
        XCTAssertTrue(session.status.contains("memory only"))
        XCTAssertFalse(session.isDurable)
        XCTAssertEqual(try Data(contentsOf: url), bad)
        XCTAssertEqual(session.entries.count, 3)
        XCTAssertEqual(session.entries[0].attachments.count, 1)
    }

    func testFailedWriteRemainsVisibleUntilAllWorkIsSaved() throws {
        let root = file().deletingLastPathComponent()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocker = root.appending(path: "blocked")
        try Data("A file prevents creation of the notebook directory.".utf8).write(to: blocker)
        let url = blocker.appending(path: "notebook.json")
        let session = DegreeSession(url: url)
        session.saveExperiment(title: "First unsaved investigation", note: "This record must survive a later successful write.")
        XCTAssertFalse(session.isDurable)
        XCTAssertNotNil(session.error)
        XCTAssertNotNil(session.persistenceWarning)
        XCTAssertTrue(session.status.contains("memory only"))
        session.error = nil
        XCTAssertNotNil(session.persistenceWarning)
        try FileManager.default.removeItem(at: blocker)
        session.saveExperiment(title: "Recovered investigation", note: "The entire in-memory notebook is now persisted.")
        XCTAssertTrue(session.isDurable)
        XCTAssertNil(session.persistenceWarning)
        XCTAssertNil(session.error)
        XCTAssertFalse(session.status.contains("memory only"))
        let loaded = DegreeSession(url: url)
        XCTAssertNil(loaded.error)
        XCTAssertTrue(loaded.isDurable)
        XCTAssertEqual(loaded.entries.map(\.title), ["Recovered investigation", "First unsaved investigation"])
    }

    func testEachLessonOpensSupportedStateAndRetainsIdentity() {
        let session = DegreeSession(url: file())
        XCTAssertEqual(Set(DegreeCurriculum.lessons.map(\.id)).count, DegreeCurriculum.lessons.count)
        for lesson in DegreeCurriculum.lessons {
            XCTAssertNotNil(LabKind(rawValue: lesson.labID))
            session.open(lesson)
            XCTAssertEqual(session.selectedLessonID, lesson.id)
            XCTAssertEqual(session.state.kind.rawValue, lesson.labID)
            XCTAssertTrue(session.evaluation.readouts.allSatisfy { $0.value.isFinite })
            session.saveExperiment(title: lesson.title, note: lesson.mathTask)
            XCTAssertEqual(session.entries.first?.sourceIDs, lesson.sourceIDs)
        }
        XCTAssertEqual(session.investigatedLessons.count, DegreeCurriculum.lessons.count)
    }

    func testAllControlsAndRestorationUnderRepeatedEdits() {
        let url = file(), session = DegreeSession(url: url)
        for cycle in 0..<12 {
            for kind in LabKind.allCases {
                session.open(kind)
                for p in LabCatalog.definition(for: kind).parameters {
                    session.set(p.id, cycle % 2 == 0 ? p.range.upperBound : p.range.lowerBound)
                }
                let expected = session.state
                session.saveExperiment(title: "\(kind.rawValue)-\(cycle)", note: "Boundary experiment")
                session.open(.tone)
                session.restore(session.entries[0])
                XCTAssertEqual(session.state, expected)
                XCTAssertTrue(session.evaluation.waveform.allSatisfy(\.isFinite))
            }
        }
        let restored = DegreeSession(url: url)
        XCTAssertEqual(restored.entries.count, 12 * LabKind.allCases.count)
        XCTAssertEqual(restored.state, session.state)
    }

    func testProjectSubmissionRequiresBothLensesAndActualEvidence() {
        let session = DegreeSession(url: file()), project = DegreeCurriculum.projects[0]
        XCTAssertFalse(session.submitProject(project))
        session.saveExperiment(title: "Voice evidence", note: "An actual saved model")
        var draft = session.project(project.id)
        draft.statement = "A designed voice"
        draft.mathReasoning = "The partial frequency model explains the selected spectral relationships."
        draft.musicalReasoning = "The sparse upper partials support the intended quiet musical phrase."
        draft.checkedCriteria = Set(project.acceptanceCriteria.indices)
        draft.evidenceIDs = [session.entries[0].id]
        session.updateProject(draft)
        XCTAssertTrue(session.submitProject(project))
        XCTAssertEqual(session.entries[0].projectID, project.id)
        XCTAssertTrue(session.entries[0].note.contains("no automatic"))
        XCTAssertNotNil(session.project(project.id).submittedAt)
    }
}
