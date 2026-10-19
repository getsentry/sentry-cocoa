# Crash E2E harness

Run crash scenarios and verify the reports delivered on the following launch:

```sh
./TestApps/CrashE2E/run-crash-e2e.sh --platform ios --reporter KSCrash \
  --scenarios ns-exception-rethrow,cpp-exception-v1,objc-object-after-caught-cpp,sigterm,kscrash-per-report-retry \
  --keep-artifacts
```

Use `--help` for device selection, build reuse, artifact paths, and other options. Project generation goes through `make xcode-ci-CrashE2E`.

## Runner regression tests

These standalone macOS tests do not build the SDK or require a simulator:

```sh
swift test --package-path TestApps/CrashE2E/Runner
```

They cover stale `launchd` entries, launch failures, malformed PIDs, live processes, exits before/after observation, unreaped processes, cleanup, and timeout diagnostics. Orchestration tests use a Swift command-execution fake to configure results/errors and inspect calls, without shell helpers or fake executables on `PATH`. Process-exit observation is still tested against real host processes; a few small subprocess integration tests check the production command adapter separately. The Crash E2E workflow runs them before the scenarios.

## Stack-capture feasibility probe

The workflow also runs `DiagnosticsProbe/probe.py` on its SentryCrash iOS matrix leg and uploads `crash-e2e-stack-probe` **even on success**. This is a feasibility check, not yet a replacement for the runner's `sample` diagnostics.

The opt-in probe requires root for `spindump`, but its disposable target runs as the normal runner user. It checks target-only binary stackshot collection, report generation after the target exits, repeated SIGTERM/SIGKILL interruption during collection, and raw-data preservation when report generation times out. The target has a named blocked frame and a heartbeat; it must remain responsive and exit cooperatively without any resume operation. Results, command timings/output, raw captures, reports, and target symbols are retained. These checks cannot prove the absence of every cancellation race; collector ownership of suspension must also be reviewed before adoption.

Local orchestration checks do not require sudo:

```sh
python3 -m unittest discover -s TestApps/CrashE2E/DiagnosticsProbe -v
```

For an explicitly privileged live probe, use a fresh output directory:

```sh
sudo -n "$(command -v python3)" TestApps/CrashE2E/DiagnosticsProbe/probe.py \
  --artifacts /tmp/crash-e2e-stack-probe \
  --target-uid "$(id -u)" --target-gid "$(id -g)"
```

## iOS termination and diagnostics

Simulator apps run as host processes but are _not_ children of the runner. A successful `simctl launch` only confirms the launch command succeeded; its exit status is not the app's exit status.

The runner parses the launched PID and registers a kernel `NOTE_EXIT` event. This observes process termination, including an unreaped process, without depending on `launchd` removing its job registration. An already-exited PID is accepted and any other observation error fails the scenario. Once registered, the observation stays tied to that process even if its PID is reused. This protection does not cover the gap between launch and registration: `simctl` returns only a PID, so the runner cannot identify reuse that already happened in that gap. Registration happens immediately to minimize that window. Deadlines use a monotonic clock.

Each launch writes an `ios-<scenario>-launch-<sequence>` artifact directory containing the launch command/result and redirected app stdout/stderr. A termination timeout also captures:

- the failing phase, observed PID, and app-exit deadline (`timeout.log`)
- host process state before and after sampling (`process.log`, `process-after-sample.log`)
- a best-effort stack sample of the still-running process (`sample.txt`, `sample-command.log`)
- host load and memory statistics (`host-load.log`, `host-memory.log`)
- simulator `launchd` state in `launchctl.log` (for diagnostics only)

Command logs include the scenario phase, app state, attempt number, time budget, elapsed time, stdout/stderr, and final exit status or signal—even when the command timed out. Simulator-management commands are recorded in `ios-<scenario>-commands`. Scenario failures have a separate `ios-<scenario>-failure.log`; cleanup failures are recorded alongside it. Exhausted simulator-control retries also capture host load and memory statistics.

Diagnostic subprocesses have their own bounded timeouts. Diagnostic collection does not turn a failed termination wait into success or increase the scenario's termination deadline. The observer only detects termination and not whether a run was successful.

A non-termination failure still represents a possible real hang. Use the process sample and app logs to distinguish startup, crash handling, drain, and SDK shutdown hangs from simulator service problems. The harness does not change crash-recorder behavior or relax the crash/report assertions.

### Simulator recovery

The runner distinguishes an unknown app state from a confirmed stop. Stop confirmation remains valid until another launch is requested; a failed launch request makes the state unknown again. Switching simulators also invalidates that confirmation.

Two simulator-management operations can retry a timeout: terminating the app and looking up its data container. They use a 10-second attempt followed by one 30-second attempt. Subprocess termination grace periods are additional. Termination is idempotent, and container lookup is read-only; neither retry executes the app or discards its reports. Other command errors are not retried, and every attempt remains in the logs.

App launches, app-exit waits, and report assertions are never retried into success. If simulator-control retries are exhausted, the scenario is reported as incomplete due to infrastructure failure, not as an SDK assertion failure or a pass. The run remains failed; `--keep-going` can execute later scenarios only after isolation is established.

### Failure handling

When an iOS scenario fails, the runner first confirms that the app has stopped:

- a process observer's exit notification is sufficient
- any simulator termination error is logged
- without an observer, `simctl` must confirm termination or report "no such process"

If termination cannot be confirmed, the run aborts (even with `--keep-going`) to preserve isolation between scenarios. Both the original scenario error and the cleanup error are reported.

Once the app has stopped, the runner attempts to preserve SDK's cache directories in `ios-<scenario>-failed-cache`. It uses the container path acquired for that scenario, without another simulator query. If setup never acquired a container, the log explains why no cache snapshot is available. An aborted run lists the scenarios that were not executed.

### Expected failures

Cleanup also applies to scenarios with known SDK gaps. Only report assertion failures qualify as expected failures; launch errors, process-observation errors, timeouts, and report I/O errors remain test failures.

### Keeping artifacts

CI uploads artifacts on failure. For local debugging, use `--keep-artifacts` to retain them after the run.
