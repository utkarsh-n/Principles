import unittest
import runtime_qa


class RuntimeGateTests(unittest.TestCase):
    def valid(self):
        return dict(sourceFingerprint="current", stressPassed=True,
                    largeTextPassed=True, sourceUnchanged=True, contentSizeRestored=True)

    def test_compilation_receipt_cannot_authorize_phone_qa(self):
        self.assertFalse(runtime_qa.gate_valid(dict(sourceFingerprint="current", exitCode=0), "current"))

    def test_partial_runtime_success_cannot_authorize_phone_qa(self):
        for key in ("stressPassed", "largeTextPassed", "sourceUnchanged", "contentSizeRestored"):
            receipt = self.valid()
            receipt[key] = False
            self.assertFalse(runtime_qa.gate_valid(receipt, "current"), key)

    def test_stale_source_cannot_authorize_phone_qa(self):
        self.assertFalse(runtime_qa.gate_valid(self.valid(), "changed"))

    def test_complete_current_runtime_receipt_authorizes_gate_only(self):
        self.assertTrue(runtime_qa.gate_valid(self.valid(), "current"))

    def test_pass_parser_excludes_failed_and_skipped_tests(self):
        log = """Test Case 'ModelTests.testPeriod' passed (0.001 seconds).
Test case 'HarmonicUITests.testControl' passed on 'Harmonic QA' (1.00 seconds).
Test Case 'ModelTests.testFailure' failed (0.001 seconds).
Test Case 'ModelTests.testSkipped' skipped (0.001 seconds).
Test Build Succeeded; testUnexecuted was compiled.
"""
        self.assertEqual(runtime_qa.passed_tests(log), {"testPeriod", "testControl"})

    def test_required_tests_include_current_guided_and_startup_paths(self):
        names = runtime_qa.expected_tests()
        self.assertIn("testImmediateEditAndStopUseAcceptedIntentBeforeFirstPoll", names)
        self.assertNotIn(runtime_qa.LARGE_TEST, names)
        self.assertFalse(any(name.startswith("testPhysical") for name in names))


if __name__ == "__main__":
    unittest.main()
