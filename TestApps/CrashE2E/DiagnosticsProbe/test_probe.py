import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from probe import Command, Target, assert_report, capture_arguments, digest, render_arguments, run


class ProbeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)

    def test_command_records_output_and_exit_status(self):
        result = run(self.directory, "success", [sys.executable, "-c", "print('evidence')"])
        self.assertEqual(result["returncode"], 0)
        self.assertFalse(result["timed_out"])
        self.assertEqual((self.directory / "success.stdout.log").read_text(), "evidence\n")
        self.assertEqual(json.loads((self.directory / "success.json").read_text()), result)

    def test_command_failure_is_not_success(self):
        with self.assertRaisesRegex(AssertionError, "failed"):
            run(self.directory, "failure", [sys.executable, "-c", "raise SystemExit(7)"])
        result = json.loads((self.directory / "failure.json").read_text())
        self.assertEqual(result["returncode"], 7)

    def test_timeout_preserves_existing_capture_and_records_failure(self):
        raw = self.directory / "raw.spindump"
        raw.write_bytes(b"existing stackshot data")
        before = digest(raw)
        command = Command(self.directory, "timeout", [sys.executable, "-c", "import time; time.sleep(60)"])
        result = command.finish(0.05)
        self.assertTrue(result["timed_out"])
        self.assertIsNotNone(result["returncode"])
        self.assertEqual(digest(raw), before)

    def test_capture_and_render_are_separate_commands(self):
        raw = self.directory / "raw.spindump"
        capture = capture_arguments(123, raw)
        self.assertEqual(capture[:4], ["/usr/sbin/spindump", "123", "2", "10"])
        self.assertIn("-onlyTarget", capture)
        self.assertIn("-noText", capture)
        render = render_arguments(raw, self.directory / "stacks.txt")
        self.assertEqual(render[1:3], ["-i", str(raw)])
        self.assertNotIn("123", render)

    def test_empty_report_does_not_count_as_stack_evidence(self):
        report = self.directory / "empty.txt"
        report.write_text("Data Source: Stackshots\n")
        with self.assertRaisesRegex(AssertionError, "blocked frame"):
            assert_report(report)

    @unittest.skipUnless(sys.platform == "darwin", "macOS target integration test")
    def test_target_heartbeat_and_cooperative_exit(self):
        executable = self.directory / "target"
        source = Path(__file__).resolve().parent / "Sources" / "target.c"
        subprocess.run(["xcrun", "clang", "-g", "-O0", "-pthread", str(source), "-o", str(executable)], check=True)
        # Passing user/group explicitly requires root, so omit them for the local test.
        with Target(self.directory, "target-process", executable, None, None) as target:
            target.require_heartbeat()
            self.assertNotEqual(target.command.process.pid, os.getpid())
        result = json.loads((self.directory / "target-process.json").read_text())
        self.assertEqual(result["returncode"], 0)
        self.assertFalse(result["timed_out"])


if __name__ == "__main__":
    unittest.main()
