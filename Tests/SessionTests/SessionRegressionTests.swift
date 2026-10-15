import XCTest
import HarmonicCore
@testable import Harmonic

@MainActor
final class SessionRegressionTests: XCTestCase {
    private func file() -> URL { FileManager.default.temporaryDirectory.appending(path: "HarmonicRegression/\(UUID().uuidString)/notebook.json") }

    func testProjectAttachmentSurvivesOriginalDeletionAndRelaunch() {
        let url = file(), session = DegreeSession(url: url)
        session.open(.composition)
        session.setHarmonic(4, 0.73)
        session.setStep(0, 75)
        session.saveExperiment(title: "Retained phrase", note: "Unique evidence wording: preserve the high partial and first pitch.")
        let original = session.entries[0]
        let project = DegreeCurriculum.projects[0]
        var draft = session.project(project.id)
        draft.statement = "An inspectable test artifact"
        draft.mathReasoning = "The stored frequencies follow the declared equal-tempered model."
        draft.musicalReasoning = "The sparse phrase is intended to leave space between attacks."
        draft.checkedCriteria = Set(project.acceptanceCriteria.indices)
        draft.evidenceIDs = [original.id]
        session.updateProject(draft)
        XCTAssertTrue(session.submitProject(project))
        XCTAssertEqual(session.entries[0].attachments.count, 1)
        XCTAssertEqual(session.entries[0].attachments[0].state, original.state)
        session.delete(original.id)
        let loaded = DegreeSession(url: url)
        XCTAssertNil(loaded.error)
        XCTAssertEqual(loaded.entries.count, 1)
        XCTAssertEqual(loaded.entries[0].attachments[0].state, original.state)
        XCTAssertTrue(loaded.entries[0].markdown.contains(original.note))
        XCTAssertTrue(loaded.entries[0].markdown.contains("75"))
        XCTAssertTrue(loaded.entries[0].markdown.contains("0.73"))
    }

    func testPredictionQuestionSurvivesMarkdownExport() {
        let session = DegreeSession(url: file())
        session.set("frequency", 440)
        session.beginPrediction()
        let question = session.pendingPrediction!
        XCTAssertTrue(session.checkPrediction(String(question.answer), note: "A changed frequency halves the period."))
        XCTAssertTrue(session.entries[0].markdown.contains(question.prompt))
        XCTAssertTrue(session.entries[0].markdown.contains("Question:"))
    }

    func testDeletingEvidenceClearsDraftSelectionAndAllowsReplacementSubmission() {
        let url = file(), session = DegreeSession(url: url)
        session.saveExperiment(title: "Original evidence", note: "The first saved experiment remains captured in its submission.")
        let original = session.entries[0]
        let project = DegreeCurriculum.projects[0]
        var draft = session.project(project.id)
        draft.statement = "A revised argument with replaceable live evidence"
        draft.mathReasoning = "The declared equation determines the generated frequencies."
        draft.musicalReasoning = "The revision preserves the chosen contrast between phrases."
        draft.checkedCriteria = Set(project.acceptanceCriteria.indices)
        draft.evidenceIDs = [original.id]
        session.updateProject(draft)
        XCTAssertTrue(session.submitProject(project))
        let firstSubmission = session.entries[0]
        session.delete(original.id)
        XCTAssertTrue(session.project(project.id).evidenceIDs.isEmpty)
        XCTAssertEqual(session.entries.first { $0.id == firstSubmission.id }?.attachments, [original])
        session.saveExperiment(title: "Replacement evidence", note: "A changed experiment supports the revised claim.")
        let replacement = session.entries[0]
        draft = session.project(project.id)
        draft.evidenceIDs = [replacement.id]
        session.updateProject(draft)
        XCTAssertTrue(session.submitProject(project))
        XCTAssertEqual(session.entries[0].attachments, [replacement])
        let restored = DegreeSession(url: url)
        XCTAssertNil(restored.error)
        XCTAssertEqual(restored.project(project.id).evidenceIDs, [replacement.id])
        XCTAssertEqual(restored.entries.first { $0.id == firstSubmission.id }?.attachments, [original])
    }

    func testReviewRemainsPendingUntilANewMatchedAnswer() {
        let session = DegreeSession(url: file())
        session.set("frequency", 440)
        session.beginPrediction()
        XCTAssertTrue(session.checkPrediction(String(session.pendingPrediction!.answer), note: "Original numerical demonstration."))
        let original = session.entries[0]
        session.beginReview(original)
        XCTAssertTrue(session.reviews.contains { $0.id == original.id })
        session.set("frequency", 660)
        session.beginPrediction()
        XCTAssertFalse(session.checkPrediction("-99", note: "A wrong new case must remain available for review."))
        XCTAssertTrue(session.reviews.contains { $0.id == original.id })
        session.beginPrediction()
        XCTAssertTrue(session.checkPrediction(String(session.pendingPrediction!.answer), note: "Reconstructed the inverse relation at a changed frequency."))
        XCTAssertFalse(session.reviews.contains { $0.id == original.id })
        XCTAssertNotNil(session.entries.first { $0.id == original.id }?.reviewedAt)
        XCTAssertTrue(session.reviews.contains { $0.id != original.id })
    }

    func testUpdatingStaleDraftCannotRestoreDeletedOrSubmittedEvidence() {
        let url = file(), session = DegreeSession(url: url)
        session.saveExperiment(title: "Original investigation", note: "The retained submission must keep a copy of this investigation.")
        let original = session.entries[0]
        let project = DegreeCurriculum.projects[0]
        var stale = session.project(project.id)
        stale.statement = "A draft kept open in another tab"
        stale.mathReasoning = "The model's declared equation explains the changed parameter."
        stale.musicalReasoning = "The musical decision preserves the intended phrase structure."
        stale.checkedCriteria = Set(project.acceptanceCriteria.indices)
        stale.evidenceIDs = [original.id]
        session.updateProject(stale)
        XCTAssertTrue(session.submitProject(project))
        let firstSubmission = session.entries[0]
        session.delete(original.id)
        session.updateProject(stale)
        XCTAssertTrue(session.project(project.id).evidenceIDs.isEmpty, "Editing a stale view draft must not revive a deleted reference")
        session.saveExperiment(title: "Replacement investigation", note: "An eligible replacement provides the current design evidence.")
        let replacement = session.entries[0]
        stale.evidenceIDs = [original.id, firstSubmission.id, replacement.id]
        session.updateProject(stale)
        XCTAssertEqual(session.project(project.id).evidenceIDs, [replacement.id], "Submitted projects are historical snapshots, not attachable investigations")
        XCTAssertTrue(session.submitProject(project))
        XCTAssertEqual(session.entries[0].attachments, [replacement])
        let restored = DegreeSession(url: url)
        XCTAssertNil(restored.error)
        XCTAssertEqual(restored.project(project.id).evidenceIDs, [replacement.id])
        XCTAssertEqual(restored.entries.first { $0.id == firstSubmission.id }?.attachments, [original])
    }

    func testKeyboardVoiceCapRefusesInertFifthSelection() {
        let session = DegreeSession(url: file())
        for note in 60...64 { session.toggleNote(note) }
        XCTAssertEqual(session.state.notes, [60,61,62,63])
        XCTAssertTrue(session.status.contains("Four keys"))
        session.toggleNote(61)
        session.toggleNote(64)
        XCTAssertEqual(session.state.notes, [60,62,63,64])
    }

    func testCompositionHarmonicsNowChangeSavedAudioRecipe() {
        var state = LabState(kind: .composition)
        state.harmonics = [0.25,0,0.4,0,0,0.1,0,0]
        let recipe = LabModel.audio(state).sanitized(sampleRate: 48000)
        XCTAssertEqual(recipe.voices[0].amplitudes, state.harmonics)
        XCTAssertEqual(recipe.stepNotes, state.steps)
        state.harmonics[2] = 0.1
        let changed = LabModel.audio(state).sanitized(sampleRate: 48000)
        XCTAssertNotEqual(changed.voices[0].amplitudes, recipe.voices[0].amplitudes)
    }

    func testScaleAuditionSequencesAllDegreesAndChordControlsIgnoreComparisonKeys() {
        var state = LabState(kind: .scales)
        state.set(id: "root", value: 62)
        state.set(id: "mode", value: 1)
        state.notes = [60,64]
        let scale = LabModel.audio(state)
        XCTAssertTrue(scale.isSequenced)
        XCTAssertEqual(scale.stepNotes, [62,-1,64,-1,65,-1,67,-1,69,-1,70,-1,72,-1,74,-1])
        state = LabState(kind: .harmony)
        state.notes = [61,65,68]
        let major = LabModel.audio(state)
        XCTAssertEqual(major.voices.map(\.frequency), [60,64,67].map { MusicMath.frequency(midi: $0) })
        state.set(id: "quality", value: 1)
        let minor = LabModel.audio(state)
        XCTAssertEqual(minor.voices.map(\.frequency), [60,63,67].map { MusicMath.frequency(midi: $0) })
        XCTAssertNotEqual(major, minor)
    }
}
