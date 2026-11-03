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

## Live timeout-path test

`harness-timeout` is an explicit opt-in scenario, excluded from `Config` defaults and both reporter-specific default lists. It starts the real app and SDK, logs readiness with its PID, and waits indefinitely in `crashE2EHarnessTimeoutWait`. In UI apps the wait runs on a background thread to avoid testing the OS's main-thread watchdog instead of the runner's deadline. It is not an SDK crash trigger or a known-failure exemption.

`HarnessTimeoutIntegrationTests` is skipped by the ordinary Swift test command. When enabled, it invokes the built Swift runner with `--scenarios harness-timeout,signal --keep-going --skip-build --keep-artifacts`. The runner must still exit with status 1 for exactly the original app-exit timeout. The outer test requires SDK startup/readiness for that PID before the unchanged 25-second deadline, successful stack collection with a symbolicated waiting frame, observer-confirmed cleanup before the next scenario, and a passing `signal` crash/drain. Setup, launch, readiness, authorization, collection, cleanup, or following-scenario failures cannot substitute for that result. The scenario is not retried.

Build and run a normal scenario first, then run the live test as your normal user (from the repository root):

```sh
env -u SDKROOT ./TestApps/CrashE2E/run-crash-e2e.sh \
  --platform ios --reporter SentryCrash --scenarios signal --quiet-build

# Requires existing non-interactive authorization for sudo -n /usr/sbin/spindump.
# If needed, authenticate with sudo -v in your own terminal, not by running Swift as root.
OUT="$PWD/DerivedData/crash-e2e-harness-timeout-$(date +%s)"
env -u SDKROOT \
  CRASH_E2E_HARNESS_TIMEOUT_TEST=1 \
  CRASH_E2E_TEST_REPORTER=SentryCrash \
  CRASH_E2E_TEST_DERIVED_DATA="$PWD/DerivedData/CrashE2E" \
  CRASH_E2E_TEST_ARTIFACTS="$OUT" \
  swift test --package-path TestApps/CrashE2E/Runner --filter HarnessTimeoutIntegrationTests
```

Use a fresh artifact directory under the workspace, not `/tmp`: simulator runtimes can remap `/tmp` redirects into their own filesystem, leaving the host artifact directory without app logs. Artifacts are retained on success and failure; the test refuses an existing directory. `runner-output.log` is outside the runner's own artifact directory so its reset cannot erase the transcript. Optional `CRASH_E2E_TEST_IOS_DEVICE_ID` and `CRASH_E2E_TEST_IOS_DESTINATION` select the simulator. To test KSCrash, build with `--reporter KSCrash` and set `CRASH_E2E_TEST_REPORTER=KSCrash`.

CI runs this test on both iOS reporter legs **after** the ordinary E2E step, reusing its build products and keeping its result unchanged. Separate `crash-e2e-harness-timeout-<reporter>` artifacts are uploaded even on success. The CI step/job provides the outer time bound; the test does not interrupt the collector with a second short timeout. This verifies diagnostics and recovery, not a fix for unexpected SDK/app hangs.

## iOS termination and diagnostics

Simulator apps run as host processes but are _not_ children of the runner. A successful `simctl launch` only confirms the launch command succeeded; its exit status is not the app's exit status.

The runner parses the launched PID and registers a kernel `NOTE_EXIT` event. This observes process termination, including an unreaped process, without depending on `launchd` removing its job registration. An already-exited PID is accepted and any other observation error fails the scenario. Once registered, the observation stays tied to that process even if its PID is reused. This protection does not cover the gap between launch and registration: `simctl` returns only a PID, so the runner cannot identify reuse that already happened in that gap. Registration happens immediately to minimize that window. Deadlines use a monotonic clock.

Each launch writes an `ios-<scenario>-launch-<sequence>` artifact directory containing the launch command/result and redirected app stdout/stderr. A termination timeout also captures:

- the failing phase, observed PID, and app-exit deadline (`timeout.log`)
- host process state before and after stack collection (`process.log`, `process-after-stackshot.log`)
- a best-effort symbolicated kernel stackshot of the still-running process (`stackshot.spindump`, `stackshot-command.log`)
- an explicit `stackshot-unavailable.log` if collection fails or saves no nonempty report
- host load and memory statistics (`host-load.log`, `host-memory.log`)
- simulator `launchd` state in `launchctl.log` (for diagnostics only)

Command logs include the scenario phase, app state, attempt number, time budget, elapsed time, stdout/stderr, and final exit status or signal—even when the command timed out. Simulator-management commands are recorded in `ios-<scenario>-commands`. Scenario failures have a separate `ios-<scenario>-failure.log`; cleanup failures are recorded alongside it. Exhausted simulator-control retries also capture host load and memory statistics.

Stack collection uses `sudo -n /usr/sbin/spindump` with a two-second sampling duration and a **requested 60-second collection/symbolication budget** via `-timelimit`. Symbolication is ordinary work that can take longer under CI load. A single invocation saves readable stacks and binary data; there is no separate rendering stage.

The requested budget is **not an independent hard wall-clock watchdog**. The runner does not kill the sudo wrapper on another short deadline. The enclosing CI job supplies the hard outer limit; outside CI there is no additional collector deadline. Other diagnostic commands retain their bounded timeouts. This is an explicit tradeoff, not a guarantee that every capture will finish within 60 seconds.

Unlike a client-managed suspend/resume sequence, [kernel stackshots](https://github.com/apple-oss-distributions/xnu/blob/main/doc/observability/mt_stackshot.md) finish their kernel rendezvous before returning to user space. Interrupting the collector therefore does not require the runner to resume the target. Collection remains best-effort: unavailable non-interactive sudo is recorded, followed by the remaining diagnostics and cleanup, without prompting or falling back to an externally interrupted `sample`. Any report written before a collector error is retained. Only the collector runs privileged; do not run the build, runner, or app as root.

Diagnostic collection does not turn a failed termination wait into success or increase the scenario's termination deadline, even if the app exits while stacks are being collected. The observer only detects termination and not whether a run was successful.

A non-termination failure still represents a possible real hang. Use the stackshot and app logs to distinguish startup, crash handling, drain, and SDK shutdown hangs from simulator service problems. The harness does not change crash-recorder behavior or relax the crash/report assertions.

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

CI uploads ordinary scenario artifacts on failure and live timeout-test artifacts even on success. For local debugging, use `--keep-artifacts` to retain artifacts after a runner invocation.
