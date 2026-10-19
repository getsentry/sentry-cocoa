#!/usr/bin/env python3
"""Opt-in macOS stackshot feasibility probe; never used by the scenario runner."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import pwd
import signal
import subprocess
import sys
import time


def wait_until(predicate, timeout, description):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError(f"Timed out waiting for {description}")


class Command:
    def __init__(self, directory, name, arguments, **kwargs):
        self.path = directory / name
        self.arguments = [str(value) for value in arguments]
        self.started = time.monotonic()
        if kwargs.get("user") is not None:
            # A non-root UID must not inherit the privileged probe's supplementary groups.
            username = pwd.getpwuid(kwargs["user"]).pw_name
            groups = os.getgrouplist(username, kwargs["group"])
            # Darwin's directory-service membership list can exceed setgroups' limit.
            # The primary GID is set separately; this fixture only needs a bounded subset.
            supplementary = [group for group in groups if group != kwargs["group"]]
            kwargs["extra_groups"] = supplementary[:os.sysconf("SC_NGROUPS_MAX")]
        self.stdout = self.path.with_suffix(".stdout.log").open("wb")
        self.stderr = self.path.with_suffix(".stderr.log").open("wb")
        try:
            self.process = subprocess.Popen(
                self.arguments, stdout=self.stdout, stderr=self.stderr, **kwargs
            )
        except Exception:
            self.stdout.close()
            self.stderr.close()
            raise

    def finish(self, timeout):
        timed_out = False
        try:
            self.process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
        finally:
            self.stdout.close()
            self.stderr.close()
        result = {
            "command": self.arguments,
            "pid": self.process.pid,
            "returncode": self.process.returncode,
            "timed_out": timed_out,
            "elapsed_seconds": time.monotonic() - self.started,
        }
        self.path.with_suffix(".json").write_text(json.dumps(result, indent=2) + "\n")
        return result


def run(directory, name, arguments, timeout=75, **kwargs):
    result = Command(directory, name, arguments, **kwargs).finish(timeout)
    if result["timed_out"] or result["returncode"] != 0:
        raise AssertionError(f"{name} failed: {result}; see command logs")
    return result


class Target:
    def __init__(self, directory, name, executable, uid, gid):
        self.command = Command(directory, name, [executable], user=uid, group=gid)
        self.path = self.command.path.with_suffix(".stdout.log")

    def __enter__(self):
        try:
            self.require_heartbeat()
        except BaseException:
            self.__exit__(*sys.exc_info())
            raise
        return self

    def require_heartbeat(self):
        before = self.path.stat().st_size
        wait_until(lambda: self.path.stat().st_size > before, 10, "target heartbeat")
        if self.command.process.poll() is not None:
            raise AssertionError("Target exited unexpectedly")

    def __exit__(self, exc_type, exc_value, traceback):
        self.command.process.terminate()
        result = self.command.finish(10)
        # Even on an earlier failure, save whether cleanup actually succeeded.
        if exc_type is None and (result["timed_out"] or result["returncode"] != 0):
            raise AssertionError(f"Target could not exit normally: {result}")


def capture_arguments(pid, output, duration=2, time_limit=60):
    return [
        "/usr/sbin/spindump", str(pid), str(duration), "10", "-onlyTarget",
        "-o", str(output), "-timelimit", str(time_limit),
    ]


def render_arguments(raw, output):
    return [
        "/usr/sbin/spindump", "-i", str(raw), "-o", str(output),
        "-noBinary", "-timelimit", "60",
    ]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assert_report(path):
    report = path.read_text(errors="replace")
    if "crash_e2e_probe_wait" not in report:
        raise AssertionError("Report does not contain the target's known blocked frame")
    if "Stackshots" not in report:
        raise AssertionError("Report does not identify the expected stackshot data source")


def capture_and_render(directory, executable, uid, gid):
    raw = directory / "stacks.spindump"
    with Target(directory, "capture-target", executable, uid, gid) as target:
        pid = target.command.process.pid
        run(directory, "process-before", ["/bin/ps", "-p", str(pid), "-o", "pid,ppid,state,time,%cpu,command"])
        run(directory, "capture", capture_arguments(pid, raw))
        if not raw.is_file() or raw.stat().st_size == 0:
            raise AssertionError("Capture returned success without raw stack data")
        target.require_heartbeat()
        run(directory, "process-after", ["/bin/ps", "-p", str(pid), "-o", "pid,ppid,state,time,%cpu,command"])

    # The production invocation saves readable stacks and binary data in one pass.
    assert_report(raw)
    # Optional re-reporting must also work after target exit, without altering the original.
    before = digest(raw)
    run(directory, "render", render_arguments(raw, directory / "stacks.txt"))
    assert_report(directory / "stacks.txt")
    if digest(raw) != before:
        raise AssertionError("Rendering modified the raw capture")


def interrupted_capture(directory, executable, uid, gid, termination_signal, attempt):
    name = f"interrupt-{termination_signal.name.lower()}-{attempt}"
    with Target(directory, name + "-target", executable, uid, gid) as target:
        collector = Command(directory, name, capture_arguments(
            target.command.process.pid, directory / (name + ".spindump"), duration=30
        ))
        try:
            # Do not count killing a process that has not started sampling as coverage.
            stderr = collector.path.with_suffix(".stderr.log")
            stdout = collector.path.with_suffix(".stdout.log")
            wait_until(
                lambda: "Sampling" in stderr.read_text(errors="replace") + stdout.read_text(errors="replace"),
                15, "spindump sampling announcement",
            )
            for _ in range(5):
                target.require_heartbeat()
            signal_after = time.monotonic() - collector.started
            if signal_after >= 30 or collector.process.poll() is not None:
                raise AssertionError("Missed the sampling window for interruption")
            collector.process.send_signal(termination_signal)
            collector.path.with_suffix(".signal.json").write_text(json.dumps({
                "signal": termination_signal.name, "sent_after_seconds": signal_after,
            }, indent=2) + "\n")
        finally:
            result = collector.finish(65)
        if result["timed_out"]:
            raise AssertionError("Collector exceeded its own time limit after interruption")
        if termination_signal == signal.SIGKILL and result["returncode"] != -signal.SIGKILL:
            raise AssertionError("Collector did not exit from the requested SIGKILL")
        if termination_signal == signal.SIGTERM:
            stderr = collector.path.with_suffix(".stderr.log").read_text(errors="replace")
            if result["returncode"] != -signal.SIGTERM and "Interrupted by signal 15" not in stderr:
                raise AssertionError("Collector did not acknowledge the requested SIGTERM")
        # No SIGCONT/task_resume repair: a suspended target must fail the probe.
        target.require_heartbeat()


def runner_invocation(directory, executable, uid, gid):
    output = directory / "runner.spindump"
    with Target(directory, "runner-target", executable, uid, gid) as target:
        run(directory, "runner-capture", ["/usr/bin/sudo", "-n", *capture_arguments(
            target.command.process.pid, output
        )], user=uid, group=gid)
        assert_report(output)
        target.require_heartbeat()


def native_time_limit(directory, executable, uid, gid):
    with Target(directory, "time-limit-target", executable, uid, gid) as target:
        # -siginfo deliberately withholds reporting until a signal we never send.
        # spindump requires its time limit to exceed the sampling duration.
        collector = Command(directory, "native-time-limit", [*capture_arguments(
            target.command.process.pid, directory / "time-limit.spindump", duration=1, time_limit=5
        ), "-siginfo"])
        # This is an observation of an artificial wait, not a normal-capture requirement.
        # Some OS versions outlast -timelimit in this mode. Preserve that fact explicitly.
        result = collector.finish(30)
        stderr = collector.path.with_suffix(".stderr.log").read_text(errors="replace")
        if "Sampling" not in stderr:
            raise AssertionError("spindump did not start the time-limit experiment")
        target.require_heartbeat()

    observation = {
        "experiment": "native-time-limit-with-siginfo (not used by the runner)",
        "requested_seconds": 5,
        "probe_timeout_seconds": 30,
        "probe_timed_out": result["timed_out"],
        "elapsed_seconds": result["elapsed_seconds"],
        "returncode": result["returncode"],
        "target_responsive_and_exited": True,
    }
    (directory / "observations.json").write_text(json.dumps(observation, indent=2) + "\n")
    return observation


def interrupted_render(directory):
    raw = directory / "stacks.spindump"
    before = digest(raw)
    # Stop the renderer before exec, deterministically modeling a stuck rendering phase.
    # It never touches the target. A subsequent real render must still work.
    command = Command(directory, "render-timeout", [
        "/bin/sh", "-c", 'kill -STOP $$; exec "$@"', "probe-render",
        *render_arguments(raw, directory / "interrupted.txt"),
    ])
    result = command.finish(0.1)
    if not result["timed_out"]:
        raise AssertionError("Expected the deliberately stalled renderer to time out")
    if digest(raw) != before:
        raise AssertionError("Interrupted rendering modified the raw capture")
    run(directory, "render-recovery", render_arguments(raw, directory / "recovered.txt"))
    assert_report(directory / "recovered.txt")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--target-uid", type=int, required=True)
    parser.add_argument("--target-gid", type=int, required=True)
    args = parser.parse_args()
    if os.geteuid() != 0 or args.target_uid == 0:
        parser.error("Run this opt-in probe as root, with a non-root target UID/GID")
    directory = args.artifacts.resolve()
    directory.mkdir(parents=True, exist_ok=False)
    os.chmod(directory, 0o755)
    executable = directory / "crash-e2e-stack-probe"
    source = Path(__file__).resolve().parent / "Sources" / "target.c"
    run(directory, "environment", ["/usr/bin/sw_vers"])
    Command(directory, "spindump-help", ["/usr/sbin/spindump", "-help"]).finish(10)
    run(directory, "host-load", ["/usr/bin/uptime"])
    run(directory, "cpu-count", ["/usr/sbin/sysctl", "hw.logicalcpu"])
    run(directory, "build-target", ["/usr/bin/xcrun", "clang", "-g", "-O0", "-pthread", source, "-o", executable])
    run(directory, "target-symbols", ["/usr/bin/xcrun", "dsymutil", executable])

    checks = [("capture-and-render", lambda: capture_and_render(
        directory, executable, args.target_uid, args.target_gid
    ))]
    for sig in [signal.SIGTERM, signal.SIGKILL]:
        for attempt in range(3):
            checks.append((f"{sig.name}-{attempt}", lambda sig=sig, attempt=attempt: interrupted_capture(
                directory, executable, args.target_uid, args.target_gid, sig, attempt
            )))
    checks.append(("interrupted-render", lambda: interrupted_render(directory)))
    checks.append(("runner-invocation", lambda: runner_invocation(
        directory, executable, args.target_uid, args.target_gid
    )))
    results = []
    for name, check in checks:
        try:
            check()
            results.append({"check": name, "passed": True})
        except Exception as error:
            results.append({"check": name, "passed": False, "error": str(error)})
        print(json.dumps(results[-1]), flush=True)
        (directory / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    try:
        observation = native_time_limit(directory, executable, args.target_uid, args.target_gid)
        print(json.dumps({"observation": observation}), flush=True)
    except Exception as error:
        # Setup or target-safety failures still fail the probe; the artificial wait's
        # duration alone does not block the real E2E scenarios.
        results.append({"check": "native-time-limit setup/target safety", "passed": False, "error": str(error)})
        print(json.dumps(results[-1]), flush=True)
        (directory / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    sys.exit(main())
