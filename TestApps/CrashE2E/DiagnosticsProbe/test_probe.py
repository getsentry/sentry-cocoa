import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from probe import Command, Target, assert_report, capture_arguments, digest, native_time_limit, render_arguments, run


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

    def test_capture_saves_symbolicated_report_with_its_own_generous_budget(self):
        raw = self.directory / "raw.spindump"
        capture = capture_arguments(123, raw)
        self.assertEqual(capture[:4], ["/usr/sbin/spindump", "123", "2", "10"])
        self.assertIn("-onlyTarget", capture)
        self.assertNotIn("-noText", capture)
        self.assertNotIn("-noSymbolicate", capture)
        self.assertEqual(capture[-2:], ["-timelimit", "60"])
        render = render_arguments(raw, self.directory / "stacks.txt")
        self.assertEqual(render[1:3], ["-i", str(raw)])
        self.assertNotIn("123", render)

    def test_empty_report_does_not_count_as_stack_evidence(self):
        report = self.directory / "empty.txt"
        report.write_text("Data Source: Stackshots\n")
        with self.assertRaisesRegex(AssertionError, "blocked frame"):
            assert_report(report)

    def test_failed_start_closes_output_handles(self):
        with mock.patch("probe.subprocess.Popen", side_effect=ValueError("cannot start")) as popen:
            with self.assertRaisesRegex(ValueError, "cannot start"):
                Command(self.directory, "failed-start", ["/usr/bin/true"])
        self.assertTrue(popen.call_args.kwargs["stdout"].closed)
        self.assertTrue(popen.call_args.kwargs["stderr"].closed)

    def test_privilege_drop_respects_group_limit_and_sets_primary_group_separately(self):
        groups = [20, *range(100, 118)]
        process = mock.Mock(pid=123, returncode=0)
        with mock.patch("probe.pwd.getpwuid", return_value=mock.Mock(pw_name="fixture-user")), \
                mock.patch("probe.os.getgrouplist", return_value=groups), \
                mock.patch("probe.os.sysconf", return_value=16) as sysconf, \
                mock.patch("probe.subprocess.Popen", return_value=process) as popen:
            command = Command(self.directory, "identity", ["/usr/bin/true"], user=501, group=20)
            command.finish(5)

        options = popen.call_args.kwargs
        self.assertEqual(options["user"], 501)
        self.assertEqual(options["group"], 20)
        self.assertEqual(options["extra_groups"], list(range(100, 116)))
        sysconf.assert_called_once_with("SC_NGROUPS_MAX")

    def test_siginfo_wait_records_watchdog_expiry_without_claiming_normal_capture_failed(self):
        collector = mock.Mock(path=self.directory / "native-time-limit")
        collector.finish.return_value = {"timed_out": True, "returncode": -9, "elapsed_seconds": 35.0}
        collector.path.with_suffix(".stderr.log").write_text("Sampling completed, waiting for SIGINFO...")
        target = mock.MagicMock()
        target.__enter__.return_value = target
        target.command.process.pid = 123
        with mock.patch("probe.Command", return_value=collector), mock.patch("probe.Target", return_value=target):
            observation = native_time_limit(self.directory, self.directory / "target", 501, 20)
        self.assertTrue(observation["probe_timed_out"])
        self.assertEqual(observation["requested_seconds"], 5)
        self.assertEqual(observation["elapsed_seconds"], 35.0)
        self.assertEqual(observation["returncode"], -9)
        target.require_heartbeat.assert_called_once()
        self.assertEqual(json.loads((self.directory / "observations.json").read_text()), observation)

    def test_siginfo_observation_still_fails_if_target_loses_responsiveness(self):
        collector = mock.Mock(path=self.directory / "native-time-limit")
        collector.finish.return_value = {"timed_out": True, "returncode": -9, "elapsed_seconds": 35.0}
        collector.path.with_suffix(".stderr.log").write_text("Sampling completed, waiting for SIGINFO...")
        target = mock.MagicMock()
        target.__enter__.return_value = target
        target.command.process.pid = 123
        target.require_heartbeat.side_effect = AssertionError("heartbeat stalled")
        with mock.patch("probe.Command", return_value=collector), mock.patch("probe.Target", return_value=target):
            with self.assertRaisesRegex(AssertionError, "heartbeat stalled"):
                native_time_limit(self.directory, self.directory / "target", 501, 20)
        self.assertFalse((self.directory / "observations.json").exists())

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
