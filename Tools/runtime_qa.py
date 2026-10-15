#!/usr/bin/env python3
"""Run isolated simulator QA and verify the source-specific phone QA gate.

This tool never restarts shared services or interacts with a physical phone.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
from datetime import datetime
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "Documentation" / "QA"
RECEIPT = QA / "SimulatorRuntimeReceipt.json"
SIMULATOR = "C419C976-D059-4F46-9F71-4F4E6387D61A"
LARGE_TEST = "testLargeTextReadoutAndControlsRemainReachable"


def source_files(root=ROOT):
    files = []
    for directory in ("App", "Sources", "Tests", "UITests", "Principles.xcodeproj"):
        files.extend(p for p in (root / directory).rglob("*") if p.is_file()
                     and ".DS_Store" not in p.parts and "xcuserdata" not in p.parts)
    files.append(root / "project.yml")
    return sorted(files)


def fingerprint(root=ROOT):
    manifest = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in source_files(root)}
    digest = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
    return digest, manifest


def expected_tests():
    names = set()
    for folder in (ROOT / "Tests", ROOT / "UITests"):
        for path in folder.rglob("*.swift"):
            names.update(re.findall(r"\bfunc (test\w+)\s*\(", path.read_text()))
    return names - {LARGE_TEST} - {n for n in names if n.startswith("testPhysical")}


def passed_tests(log):
    names = set()
    for line in log.splitlines():
        if re.search(r"\btest\s+case\b.*\bpassed\b", line, re.IGNORECASE):
            names.update(re.findall(r"\btest[A-Z]\w*", line))
    return names


def gate_valid(receipt, current):
    return (receipt.get("sourceFingerprint") == current
            and receipt.get("stressPassed") is True
            and receipt.get("largeTextPassed") is True
            and receipt.get("sourceUnchanged") is True
            and receipt.get("contentSizeRestored") is True)


def run(command, timeout, log_path=None, env=None):
    print("Running:", " ".join(command), flush=True)
    if log_path is None:
        completed = subprocess.run(command, text=True, capture_output=True,
                                   timeout=timeout, env=env)
        if completed.returncode:
            raise RuntimeError(completed.stderr.strip() or completed.stdout.strip())
        return completed.stdout.strip()
    with log_path.open("w") as stream:
        process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                                   start_new_session=True, env=env)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGINT)
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            raise RuntimeError("QA deadline reached; only its owned Xcode process group was stopped.")
    if code:
        raise RuntimeError("Xcode exited %s; inspect %s" % (code, log_path))


def check_gate():
    current, _ = fingerprint()
    receipt = json.loads(RECEIPT.read_text()) if RECEIPT.exists() else {}
    if not gate_valid(receipt, current):
        raise RuntimeError("Phone QA remains gated: both simulator stress and large-text runtime checks must pass for the current source.")
    print("Phone QA gate passed for current source:", current)


def simulator(args):
    digest, manifest = fingerprint()
    required = expected_tests()
    if args.dry_run:
        print(json.dumps({"simulatorID": args.simulator_id,
                          "sourceFingerprint": digest,
                          "requiredNormalTests": sorted(required),
                          "requiredLargeTextTest": LARGE_TEST,
                          "physicalPhoneActions": False}, indent=2))
        return
    QA.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(ZoneInfo("America/Chicago")).strftime("%Y%m%d-%H%M%S")
    evidence = QA / ("runtime-" + stamp)
    evidence.mkdir()
    receipt = {"sourceFingerprint": digest, "simulatorID": args.simulator_id,
               "stressPassed": False, "largeTextPassed": False,
               "sourceUnchanged": False, "evidence": str(evidence)}
    RECEIPT.write_text(json.dumps(receipt, indent=2))
    (evidence / "SourceManifest.json").write_text(json.dumps(manifest, indent=2))
    stage = Path(tempfile.mkdtemp(prefix="PrinciplesRuntimeQA-"))
    for relative in manifest:
        destination = stage / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, destination)
    assert fingerprint(stage)[0] == digest
    base = ["xcodebuild", "-project", str(stage / "Principles.xcodeproj"),
            "-scheme", "Principles", "-configuration", "Debug", "-destination",
            "platform=iOS Simulator,id=" + args.simulator_id,
            "-derivedDataPath", str(stage / "DerivedData"),
            "-parallel-testing-enabled", "NO",
            # Keep assertions and xcresult attachments while avoiding an optional
            # sysdiagnose collection that can stall after runtime warnings.
            "-collect-test-diagnostics", "never"]
    old_size = None
    try:
        inventory = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "--json"], 30))
        devices = [device for group in inventory.get("devices", {}).values() for device in group]
        target = next((device for device in devices if device.get("udid") == args.simulator_id), None)
        if target is None:
            raise RuntimeError("The explicitly selected QA simulator is unavailable.")
        if target.get("state") != "Booted":
            run(["xcrun", "simctl", "boot", args.simulator_id], 30)
        run(["xcrun", "simctl", "bootstatus", args.simulator_id, "-b"], 90)
        old_size = run(["xcrun", "simctl", "ui", args.simulator_id, "content_size"], 30)
        if old_size not in {"extra-small", "small", "medium", "large", "extra-large",
                            "extra-extra-large", "extra-extra-extra-large",
                            "accessibility-medium", "accessibility-large", "accessibility-extra-large",
                            "accessibility-extra-extra-large", "accessibility-extra-extra-extra-large"}:
            raise RuntimeError("Cannot safely restore the simulator's unknown content-size setting.")
        run(["xcrun", "simctl", "ui", args.simulator_id, "content_size", "large"], 30)
        normal = evidence / "stress.log"
        normal_environment = dict(os.environ)
        normal_environment.pop("TEST_RUNNER_HARMONIC_LARGE_TEXT", None)
        normal_environment.pop("HARMONIC_LARGE_TEXT", None)
        run(base + ["-skip-testing:HarmonicUITests/HarmonicHardwareUITests",
                    "-resultBundlePath", str(evidence / "Stress.xcresult"), "test"],
            args.timeout, normal, normal_environment)
        missing = required - passed_tests(normal.read_text())
        if missing:
            raise RuntimeError("Required tests did not report passes: " + ", ".join(sorted(missing)))
        receipt["stressPassed"] = True
        run(["xcrun", "simctl", "ui", args.simulator_id, "content_size",
             "accessibility-extra-extra-extra-large"], 30)
        large = evidence / "large-text.log"
        environment = dict(os.environ, TEST_RUNNER_HARMONIC_LARGE_TEXT="1")
        run(base + ["-only-testing:HarmonicUITests/HarmonicUITests/" + LARGE_TEST,
                    "-resultBundlePath", str(evidence / "LargeText.xcresult"), "test-without-building"],
            args.timeout, large, environment)
        receipt["largeTextPassed"] = LARGE_TEST in passed_tests(large.read_text())
        receipt["sourceUnchanged"] = fingerprint()[0] == digest
        if not receipt["largeTextPassed"] or not receipt["sourceUnchanged"]:
            raise RuntimeError("Large-text validation or source parity did not pass.")
    except Exception as error:
        receipt["error"] = str(error)
        raise
    finally:
        if old_size:
            try:
                run(["xcrun", "simctl", "ui", args.simulator_id, "content_size", old_size], 30)
                receipt["contentSizeRestored"] = True
            except Exception as error:
                receipt["contentSizeRestored"] = False
                receipt["restoreError"] = str(error)
        RECEIPT.write_text(json.dumps(receipt, indent=2))
    check_gate()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("check-phone-gate")
    sim = sub.add_parser("simulator")
    sim.add_argument("--simulator-id", default=SIMULATOR)
    sim.add_argument("--timeout", type=int, default=1800)
    sim.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        check_gate() if args.command == "check-phone-gate" else simulator(args)
    except Exception as error:
        parser.exit(2, str(error) + "\n")


if __name__ == "__main__":
    main()
