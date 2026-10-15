import XCTest

@MainActor
final class HarmonicUITests: XCTestCase {
    private func launch(lab: String = "tone", reset: Bool = true, id: String = "sim-stress") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--qa-id", id, "--qa-lab", lab] + (reset ? ["--qa-reset"] : [])
        app.launch()
        XCTAssertTrue(app.buttons["audioTransport"].waitForExistence(timeout: 20))
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        if element.exists && element.isHittable { return }
        let initialCandidate = app.scrollViews.firstMatch
        let initialScroll = initialCandidate.exists && initialCandidate.isHittable ? initialCandidate : app
        let viewport = initialScroll.frame.intersection(app.frame)
        let targetFrame = element.exists ? element.frame : .null
        // Above the viewport requires a downward drag; below it requires an
        // upward drag. For an obscured in-viewport control, use its nearer edge.
        let hasFrames = !targetFrame.isEmpty && !viewport.isEmpty && targetFrame.midY.isFinite && viewport.midY.isFinite
        let upwardsFirst = hasFrames ? targetFrame.midY >= viewport.midY : true
        for upwards in [upwardsFirst, !upwardsFirst] {
            for _ in 0..<12 {
                if element.exists && element.isHittable { return }
                // Use the scroll margin so a gesture does not begin on a slider,
                // stepper, piano key or editable field that owns its touches.
                let candidate = app.scrollViews.firstMatch
                let scroll = candidate.exists && candidate.isHittable ? candidate : app
                let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: upwards ? 0.75 : 0.25))
                let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: upwards ? 0.25 : 0.75))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
        }
        XCTAssertTrue(element.isHittable, "Unreachable control: \(element)")
    }
    private func controlValue(_ element: XCUIElement) -> String { element.value as? String ?? "" }
    private func setSwitch(_ element: XCUIElement, enabled: Bool, in app: XCUIApplication) {
        reveal(element, in: app)
        let native = element.switches.firstMatch.exists ? element.switches.firstMatch : element
        let expected = enabled ? "1" : "0"
        if controlValue(native) != expected { native.tap() }
        XCTAssertEqual(controlValue(native), expected)
    }
    private func exact(_ key: String, value: String, in app: XCUIApplication) {
        let edit = app.buttons["edit-\(key)"]
        reveal(edit, in: app); edit.tap()
        let input = app.textFields["parameterText"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        if let existing = input.value as? String { input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)) }
        input.typeText(value)
        app.buttons["applyParameter"].tap()
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testAllFourteenLabsOpenAndAcceptBoundaryControls() {
        let kinds = ["tone","string","intervals","timbre","envelope","rhythm","scales","harmony","voiceLeading","resonance","sampling","filter","room","composition"]
        for kind in kinds {
            let app = launch(lab: kind, id: "route-\(kind)")
            XCTAssertTrue(app.otherElements["instrumentHero"].exists || app.staticTexts["heroReadout"].exists)
            let identifiers = app.sliders.matching(NSPredicate(format: "identifier BEGINSWITH 'param-'"))
                .allElementsBoundByIndex.map { $0.identifier }
            XCTAssertFalse(identifiers.isEmpty, "\(kind) has no scalar controls")
            XCTAssertEqual(Set(identifiers).count, identifiers.count, "Scalar identifiers must be unique")
            var startingValues: [String: String] = [:]
            for identifier in identifiers {
                let key = String(identifier.dropFirst("param-".count))
                let value = app.buttons["edit-\(key)"]
                reveal(value, in: app)
                startingValues[identifier] = controlValue(value)
                XCTAssertFalse(controlValue(value).isEmpty)
                // Requery by identifier after every scroll and change; previously
                // captured child indices are not stable accessibility targets.
                let slider = app.sliders[identifier]
                reveal(slider, in: app)
                slider.adjust(toNormalizedSliderPosition: 0)
                let lowerValue = controlValue(app.buttons["edit-\(key)"])
                XCTAssertFalse(lowerValue.isEmpty)
                app.sliders[identifier].adjust(toNormalizedSliderPosition: 1)
                let upperValue = controlValue(app.buttons["edit-\(key)"])
                XCTAssertFalse(upperValue.isEmpty)
                XCTAssertNotEqual(lowerValue, upperValue, "\(kind).\(key) did not respond at both boundaries")
            }
            let reset = app.buttons["resetLab"]
            reveal(reset, in: app)
            reset.tap()
            for identifier in identifiers {
                let key = String(identifier.dropFirst("param-".count))
                let value = app.buttons["edit-\(key)"]
                reveal(value, in: app)
                XCTAssertEqual(controlValue(value), startingValues[identifier], "\(kind).\(key) did not restore its initial value")
            }
            XCTAssertTrue(app.buttons["audioTransport"].isHittable)
            XCTAssertFalse(app.staticTexts["Unavailable"].exists)
            attach(app, "Lab \(kind)"); app.terminate()
        }
    }

    func testMapGuidedInvestigationOpensItsPresetAndReferences() {
        let app = launch(id: "guided-route")
        app.tabBars.buttons["Map"].tap()
        let module = app.buttons["module-sound"]
        reveal(module, in: app); module.tap()
        let lesson = app.buttons["lesson-tone-amplitude"]
        reveal(lesson, in: app); lesson.tap()
        let lessonEquation = app.staticTexts["Mean square of A sin(ωt) = A²/2 · ΔL = 20 log₁₀(A₂/A₁)"]
        reveal(lessonEquation, in: app)
        XCTAssertTrue(lessonEquation.isHittable)
        let source = app.descendants(matching: .any)["source-mit-production"]
        reveal(source, in: app)
        XCTAssertTrue(source.label.contains("MIT 21M.380"))
        let open = app.buttons["openLesson"]
        reveal(open, in: app); open.tap()
        XCTAssertTrue(app.buttons["audioTransport"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Amplitude is not a loudness score"].exists)
        for (key, expected) in [("frequency", "330 Hz"), ("amplitude", "0.25 relative"), ("phase", "0 °")] {
            let control = app.buttons["edit-\(key)"]
            reveal(control, in: app)
            XCTAssertEqual(controlValue(control), expected)
        }
        let studioEquation = app.staticTexts["x(t) = A sin(2πft + φ) · T = 1/f"]
        reveal(studioEquation, in: app)
        XCTAssertTrue(studioEquation.isHittable)
        reveal(app.descendants(matching: .any)["source-mit-production"], in: app)
        attach(app, "Guided amplitude investigation and provenance")
    }

    func testSimulatorForegroundSuspensionDoesNotAutomaticallyResume() {
        let app = launch(id: "foreground-suspension")
        let transport = app.buttons["audioTransport"]
        transport.tap()
        XCTAssertTrue(waitLabel(transport, contains: "Stop", timeout: 5))
        XCUIDevice.shared.press(.home)
        let backgrounded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "state == %@", NSNumber(value: XCUIApplication.State.runningBackground.rawValue)), object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [backgrounded], timeout: 5), .completed)
        app.activate()
        XCTAssertTrue(transport.waitForExistence(timeout: 10))
        XCTAssertTrue(waitLabel(transport, contains: "Audition", timeout: 5))
        let automaticResume = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Stop'"), object: transport)
        automaticResume.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [automaticResume], timeout: 2), .completed)
        attach(app, "Foreground return requires a new audition")
    }

    func testRapidAuditionsEditsAndHeldStepperRemainResponsive() {
        let app = launch()
        let transport = app.buttons["audioTransport"]
        for _ in 0..<12 {
            transport.tap()
            XCTAssertTrue(waitLabel(transport, contains: "Stop", timeout: 5))
            transport.tap()
            XCTAssertTrue(waitLabel(transport, contains: "Audition", timeout: 5))
        }
        exact("frequency", value: "440", in: app)
        let value = app.buttons["edit-frequency"]
        XCTAssertEqual(controlValue(value), "440 Hz")
        transport.tap()
        XCTAssertTrue(waitLabel(transport, contains: "Stop", timeout: 5))
        let stepper = app.steppers["stepper-frequency"]
        reveal(stepper, in: app)
        let frame = value.frame
        let increment = stepper.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'increment' OR label CONTAINS[c] 'increase'")).firstMatch
        if increment.exists { increment.press(forDuration: 1.5) }
        else { stepper.buttons.element(boundBy: max(0, stepper.buttons.count - 1)).press(forDuration: 1.5) }
        XCTAssertEqual(value.frame.origin.x, frame.origin.x, accuracy: 1)
        XCTAssertEqual(value.frame.origin.y, frame.origin.y, accuracy: 1)
        XCTAssertNotEqual(controlValue(value), "440 Hz")
        transport.tap()
        attach(app, "Held live control")
    }

    func testNotebookSaveRestoreAndRelaunchPersistence() {
        let app = launch(id: "notebook-flow")
        exact("frequency", value: "330", in: app)
        app.buttons["dockSaveRun"].tap()
        let title = app.textFields["runTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Saved 330 Hz")
        app.buttons["confirmSaveRun"].tap()
        app.tabBars.buttons["Notebook"].tap()
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Saved 330 Hz'")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5)); record.tap()
        app.buttons["restoreEntry"].tap()
        reveal(app.buttons["edit-frequency"], in: app)
        XCTAssertEqual(controlValue(app.buttons["edit-frequency"]), "330 Hz")
        app.terminate()
        _ = launch(reset: false, id: "notebook-flow")
        reveal(app.buttons["edit-frequency"], in: app)
        XCTAssertEqual(controlValue(app.buttons["edit-frequency"]), "330 Hz")
        attach(app, "Notebook restoration")
    }

    func testPredictionCapturesAnswerAndCreatesReviewEvidence() {
        let app = launch()
        exact("frequency", value: "250", in: app)
        let prediction = app.buttons["predictButton"]
        reveal(prediction, in: app); prediction.tap()
        let answer = app.textFields["predictionAnswer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5)); answer.tap(); answer.typeText("2")
        let reasoning = "Doubling 250 Hz gives 500 Hz; period = 1000 / 500 = 2 ms."
        let reasoningField = app.textFields["predictionReasoning"].exists ? app.textFields["predictionReasoning"] : app.textViews["predictionReasoning"]
        reveal(reasoningField, in: app); reasoningField.tap(); reasoningField.typeText(reasoning)
        let check = app.buttons["checkPrediction"]
        reveal(check, in: app); check.tap()
        XCTAssertTrue(app.staticTexts["predictionResult"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Prediction matched"].exists)
        attach(app, "Checked prediction")
        app.buttons["predictionDone"].tap()
        app.tabBars.buttons["Notebook"].tap()
        let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'notebookEntry-' AND label CONTAINS 'Prediction'")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5)); record.tap()
        XCTAssertTrue(app.staticTexts["Your answer: 2 ms"].exists)
        let savedReasoning = app.staticTexts["notebookReasoning"]
        reveal(savedReasoning, in: app)
        XCTAssertEqual(savedReasoning.label, reasoning)
        app.tabBars.buttons["Review"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'review-'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testReflectedPhraseCanUseLowerRegisterAndRest() {
        let app = launch(lab: "composition", id: "phrase-reflection")
        let step = app.buttons["score-1"]
        reveal(step, in: app); step.tap()
        app.buttons["Octave 3"].tap()
        let pitch = app.buttons["scorePitch-58"]
        XCTAssertTrue(pitch.waitForExistence(timeout: 5)); pitch.tap()
        XCTAssertTrue((step.value as? String ?? step.label).contains("A♯3"))
        let rest = app.buttons["score-3"]
        rest.tap(); app.buttons["Rest"].tap()
        XCTAssertTrue((rest.value as? String ?? rest.label).contains("Rest"))
        let down = app.buttons["transposePhraseDown"]
        reveal(down, in: app); down.tap()
        reveal(step, in: app)
        XCTAssertTrue((step.value as? String ?? step.label).contains("A3"))
        attach(app, "Reflected phrase and rest")
    }

    func testProjectSubmissionRetainsWrittenReasoningAndEvidence() {
        let app = launch(id: "project-flow")
        app.buttons["dockSaveRun"].tap()
        let title = app.textFields["runTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Project tuning evidence")
        let note = app.textFields["runNote"].exists ? app.textFields["runNote"] : app.textViews["runNote"]
        reveal(note, in: app); note.tap(); note.typeText("A retained tuning observation.")
        reveal(app.buttons["confirmSaveRun"], in: app)
        app.buttons["confirmSaveRun"].tap()
        app.tabBars.buttons["Projects"].tap()
        app.buttons["project-project-tuning"].tap()
        for (id, text) in [("projectStatement", "Compare two thirds for a quiet motif."), ("projectMath", "Compare frequency ratios and cents with a stated reference."), ("projectMusic", "Describe the listening result separately from the ratio.")] {
            let field = app.textFields[id].exists ? app.textFields[id] : app.textViews[id]
            reveal(field, in: app); field.tap(); field.typeText(text)
            if app.keyboards.buttons["Return"].exists { app.keyboards.buttons["Return"].tap() }
            app.swipeUp()
        }
        let evidence = app.switches.matching(NSPredicate(format: "identifier BEGINSWITH 'attach-'")).firstMatch
        setSwitch(evidence, enabled: true, in: app)
        for index in 0..<4 {
            let criterion = app.switches["criterion-\(index)"]
            setSwitch(criterion, enabled: true, in: app)
        }
        let submit = app.buttons["submitProject"]
        reveal(submit, in: app); submit.tap()
        app.tabBars.buttons["Notebook"].tap()
        let submission = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'notebookEntry-' AND label CONTAINS 'Two tunings, one musical intention'")).firstMatch
        XCTAssertTrue(submission.waitForExistence(timeout: 5)); submission.tap()
        let savedReasoning = app.staticTexts["notebookReasoning"]
        reveal(savedReasoning, in: app)
        for expected in ["Compare two thirds for a quiet motif.", "Compare frequency ratios and cents with a stated reference.", "Describe the listening result separately from the ratio."] {
            XCTAssertTrue(savedReasoning.label.contains(expected))
        }
        let attachment = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'attachment-' AND label CONTAINS 'Project tuning evidence'")).firstMatch
        reveal(attachment, in: app); attachment.tap()
        XCTAssertFalse(app.buttons["deleteEntry"].exists, "Submitted evidence is a retained snapshot, not a deletable live notebook record")
        let attachedReasoning = app.staticTexts["notebookReasoning"]
        reveal(attachedReasoning, in: app)
        XCTAssertEqual(attachedReasoning.label, "A retained tuning observation.")
        attach(app, "Project notebook submission")
    }

    func testTwoMinutePlaybackNavigationSoak() {
        let app = launch(lab: "composition", id: "soak")
        var renderedSeconds = 0.0
        var nonzeroSeconds = 0.0
        var evidence: [String] = []
        for round in 0..<12 {
            let transport = app.buttons["audioTransport"]
            transport.tap()
            XCTAssertTrue(waitLabel(transport, contains: "Stop", timeout: 5))
            let stopped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Audition'"), object: transport)
            XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 16), .completed, "Finite audition \(round) never stopped")

            // A route error or interruption also returns the transport to
            // Audition. Only the production renderer's completed deadline and
            // retained PCM counters establish a full twelve-second cycle.
            app.buttons["settingsButton"].tap()
            let rendered = app.staticTexts["renderEvidence"]
            reveal(rendered, in: app)
            let completed = XCTNSPredicateExpectation(predicate: NSPredicate(
                format: "label CONTAINS 'status=Audition complete' AND label CONTAINS 'rendering=false'"), object: rendered)
            XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 5), .completed,
                           "Audition \(round) ended without a renderer deadline completion")
            let snapshot = rendered.label
            let rate = telemetryNumber("rate", in: snapshot)
            let samples = telemetryNumber("samples", in: snapshot)
            let nonzero = telemetryNumber("nonzero", in: snapshot)
            let requested = telemetryNumber("requested", in: snapshot)
            let applied = telemetryNumber("applied", in: snapshot)
            XCTAssertGreaterThan(rate, 0)
            XCTAssertGreaterThan(requested, 0)
            XCTAssertEqual(requested, applied)
            if rate > 0 {
                XCTAssertGreaterThanOrEqual(samples, 12 * rate - 1)
                XCTAssertLessThanOrEqual(samples, 12 * rate + 0.012 * rate + 2)
                // The reset composition has eight sounding slots alternating
                // with rests. Four seconds of nonzero samples is a conservative
                // floor for its twelve-second audition, including all tapers.
                XCTAssertGreaterThanOrEqual(nonzero, 4 * rate)
                XCTAssertLessThanOrEqual(nonzero, samples)
                renderedSeconds += samples / rate
                nonzeroSeconds += nonzero / rate
            }
            evidence.append("Audition \(round + 1): \(snapshot)")
            app.buttons["settingsDone"].tap()
            app.tabBars.buttons["Map"].tap()
            XCTAssertTrue(app.buttons["startStudio"].waitForExistence(timeout: 5))
            app.tabBars.buttons["Studio"].tap()
        }
        XCTAssertGreaterThanOrEqual(renderedSeconds, 144 - 0.001)
        XCTAssertGreaterThanOrEqual(nonzeroSeconds, 48)
        evidence.append("Cumulative generated seconds=\(renderedSeconds); nonzero seconds=\(nonzeroSeconds)")
        let telemetry = XCTAttachment(string: evidence.joined(separator: "\n"))
        telemetry.name = "Twelve complete auditions — production PCM telemetry"
        telemetry.lifetime = .keepAlways
        add(telemetry)
        attach(app, "Two-minute foreground soak")
    }

    func testLargeTextReadoutAndControlsRemainReachable() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["HARMONIC_LARGE_TEXT"] == "1", "Run after setting the isolated simulator to an accessibility content size.")
        let app = launch(id: "large-text")
        let readout = app.staticTexts["accessibleHeroReadout"]
        reveal(readout, in: app)
        XCTAssertTrue(readout.frame.intersects(app.frame))
        exact("frequency", value: "330", in: app)
        XCTAssertEqual(controlValue(app.buttons["edit-frequency"]), "330 Hz")
        XCTAssertTrue(app.buttons["audioTransport"].isHittable)
        attach(app, "Accessibility-size readout and exact controls")
    }

    private func waitLabel(_ element: XCUIElement, contains: String, timeout: Double) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", contains), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
    private func telemetryNumber(_ key: String, in text: String) -> Double {
        guard let range = text.range(of: key + "=") else { return -1 }
        let value = text[range.upperBound...].prefix { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(value) ?? -1
    }
}

@MainActor
final class HarmonicHardwareUITests: XCTestCase {
    private func launch() throws -> XCUIApplication {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical audio/haptic/motion suite runs after simulator stress on a real iPhone.")
        #else
        let app = XCUIApplication(); app.launchArguments = ["--qa-id", "hardware", "--qa-reset", "--qa-lab", "tone"]
        app.launch(); XCTAssertTrue(app.buttons["audioTransport"].waitForExistence(timeout: 20)); return app
        #endif
    }
    func testPhysicalRendererRouteAndHapticSubmission() throws {
        let app = try launch()
        app.buttons["audioTransport"].tap()
        app.buttons["settingsButton"].tap()
        let renderedEvidence = app.staticTexts["renderEvidence"]
        XCTAssertTrue(renderedEvidence.waitForExistence(timeout: 5))
        // Take renderer evidence before sensory navigation can outlast the finite
        // 12-second audition. Error text is never accepted as a playing state.
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'rendering=true' AND label MATCHES %@", ".*nonzero=[1-9][0-9]{3,};.*"), object: renderedEvidence)
        XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 8), .completed)
        let snapshot = renderedEvidence.label
        XCTAssertGreaterThanOrEqual(number("nonzero", in: snapshot), 1000)
        XCTAssertGreaterThan(number("rate", in: snapshot), 0)
        XCTAssertGreaterThan(number("requested", in: snapshot), 0)
        XCTAssertEqual(number("requested", in: snapshot), number("applied", in: snapshot))
        XCTAssertTrue(snapshot.contains("route="))
        XCTAssertFalse(snapshot.contains("route=No audio output"))
        let tactileEvidence = app.staticTexts["tactileEvidence"]
        revealHardware(tactileEvidence, in: app)
        XCTAssertGreaterThan(number("events", in: tactileEvidence.label), 0)
        XCTAssertTrue(tactileEvidence.label.contains("core=true"), "Verify the actual Core Haptics submission path on this iPhone")
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Physical services and route"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["settingsDone"].tap()
        app.terminate()
    }
    func testPhysicalMotionSamplesOrRespectsReduceMotion() throws {
        let app = try launch()
        app.buttons["settingsButton"].tap()
        let enabled = nativeSwitch(app.switches["motionToggle"])
        XCTAssertEqual(enabled.value as? String, "1")
        let preference = app.staticTexts["reduceMotionEvidence"]
        revealHardware(preference, in: app)
        XCTAssertTrue(preference.label == "reduceMotion=true" || preference.label == "reduceMotion=false")
        let sensorEvidence = app.staticTexts["sensorEvidence"]
        revealHardware(sensorEvidence, in: app)
        if preference.label == "reduceMotion=true" {
            XCTAssertTrue(sensorEvidence.label.contains("active=false"))
            let status = app.staticTexts["motionStatus"]
            revealHardware(status, in: app)
            XCTAssertEqual(status.label, "Motion off")
        } else {
            let sampled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'active=true' AND label MATCHES %@", "samples=([6-9]|[1-9][0-9]+);.*"), object: sensorEvidence)
            XCTAssertEqual(XCTWaiter.wait(for: [sampled], timeout: 8), .completed)
            XCTAssertGreaterThan(number("samples", in: sensorEvidence.label), 5)
        }
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Physical motion and accessibility preference"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["settingsDone"].tap()
        app.terminate()
    }
    private func revealHardware(_ element: XCUIElement, in app: XCUIApplication) {
        if element.exists && element.isHittable { return }
        let initialCandidate = app.scrollViews.firstMatch
        let initialScroll = initialCandidate.exists && initialCandidate.isHittable ? initialCandidate : app
        let viewport = initialScroll.frame.intersection(app.frame)
        let targetFrame = element.exists ? element.frame : .null
        let hasFrames = !targetFrame.isEmpty && !viewport.isEmpty && targetFrame.midY.isFinite && viewport.midY.isFinite
        let upwardsFirst = hasFrames ? targetFrame.midY >= viewport.midY : true
        for upwards in [upwardsFirst, !upwardsFirst] {
            for _ in 0..<10 {
                if element.exists && element.isHittable { return }
                let candidate = app.scrollViews.firstMatch
                let scroll = candidate.exists && candidate.isHittable ? candidate : app
                let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: upwards ? 0.75 : 0.25))
                let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: upwards ? 0.25 : 0.75))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
        }
        XCTAssertTrue(element.isHittable)
    }
    private func nativeSwitch(_ element: XCUIElement) -> XCUIElement {
        element.switches.firstMatch.exists ? element.switches.firstMatch : element
    }
    private func setSwitch(_ element: XCUIElement, enabled: Bool, in app: XCUIApplication) {
        revealHardware(element, in: app)
        let native = nativeSwitch(element)
        let expected = enabled ? "1" : "0"
        if native.value as? String != expected { native.tap() }
        XCTAssertEqual(native.value as? String, expected)
    }
    private func number(_ key: String, in text: String) -> Double {
        let marker = key + "="
        guard let range = text.range(of: marker) else { return -1 }
        let suffix = text[range.upperBound...].prefix { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(suffix) ?? -1
    }
    func testPhysicalForegroundSuspensionDoesNotResumeAudio() throws {
        let app = try launch()
        let transport = app.buttons["audioTransport"]
        transport.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Stop'"), object: transport)], timeout: 5), .completed)
        XCUIDevice.shared.press(.home)
        let backgrounded = XCTNSPredicateExpectation(predicate: NSPredicate(
            format: "state == %@", NSNumber(value: XCUIApplication.State.runningBackground.rawValue)), object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [backgrounded], timeout: 5), .completed)
        app.activate()
        XCTAssertTrue(transport.waitForExistence(timeout: 10))
        let stopped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Audition'"), object: transport)
        XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 5), .completed)
        let automaticResume = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Stop'"), object: transport)
        automaticResume.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [automaticResume], timeout: 2), .completed)
        app.terminate()
    }
    func testPhysicalHapticsAndMotionCanBeDisabledIndependently() throws {
        let app = try launch()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.switches["hapticsToggle"].waitForExistence(timeout: 5))
        setSwitch(app.switches["hapticsToggle"], enabled: false, in: app)
        XCTAssertEqual(nativeSwitch(app.switches["motionToggle"]).value as? String, "1")
        app.buttons["settingsDone"].tap()
        app.buttons["audioTransport"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Stop'"), object: app.buttons["audioTransport"])], timeout: 5), .completed)
        app.buttons["settingsButton"].tap()
        let noHaptics = app.staticTexts["tactileEvidence"]
        revealHardware(noHaptics, in: app)
        XCTAssertEqual(number("events", in: noHaptics.label), 0, "Sound still renders without submitting disabled haptics")
        setSwitch(app.switches["motionToggle"], enabled: false, in: app)
        setSwitch(app.switches["hapticsToggle"], enabled: true, in: app)
        let motion = app.staticTexts["motionStatus"]
        revealHardware(motion, in: app)
        XCTAssertEqual(motion.label, "Motion off")
        app.buttons["settingsDone"].tap()
        // Either Stop or Audition is an accepted selection cue. It must submit
        // haptics now even though presentation motion remains disabled.
        app.buttons["audioTransport"].tap()
        app.buttons["settingsButton"].tap()
        let haptics = app.staticTexts["tactileEvidence"]
        revealHardware(haptics, in: app)
        XCTAssertGreaterThan(number("events", in: haptics.label), 0)
        let sensor = app.staticTexts["sensorEvidence"]
        revealHardware(sensor, in: app)
        XCTAssertTrue(sensor.label.contains("active=false"))
        app.buttons["settingsDone"].tap()
        app.terminate()
    }
}
