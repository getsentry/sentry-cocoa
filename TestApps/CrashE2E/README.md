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

## iOS termination and diagnostics

Simulator apps run as host processes but are _not_ children of the runner. A successful `simctl launch` only confirms the launch command succeeded; its exit status is not the app's exit status.

The runner parses the launched PID and registers a kernel `NOTE_EXIT` event. This observes process termination, including an unreaped process, without depending on `launchd` removing its job registration. An already-exited PID is accepted and any other observation error fails the scenario. Once registered, the observation stays tied to that process even if its PID is reused. This protection does not cover the gap between launch and registration: `simctl` returns only a PID, so the runner cannot identify reuse that already happened in that gap. Registration happens immediately to minimize that window. Deadlines use a monotonic clock.

Each launch writes an `ios-<scenario>-launch-<sequence>` artifact directory containing the launch command/result and redirected app stdout/stderr. A termination timeout also captures:

- host process state (`process.log`)
- a best-effort stack sample of the still-running process (`sample.txt`, `sample-command.log`)
- simulator `launchd` state in `launchctl.log` (for diagnostics only)

Diagnostic subprocesses have their own bounded timeouts. Diagnostic collection does not turn a failed termination wait into success or increase the scenario's termination deadline. The observer only detects termination and not whether a run was successful.

After any scenario failure, the runner stops the app and preserves Sentry's cache directories in `ios-<scenario>-failed-cache` before classifying the outcome. Known SDK gaps accept only report assertion failures; launch, observation, timeout, and I/O errors still fail the run. Cleanup applies to expected failures too. If the app cannot be stopped, the run aborts even with `--keep-going`, rather than clearing a cache still in use, so we can ensure that scenarios are sufficiently isolated. CI uploads artifacts on failure, for local investion use `--keep-artifacts` so they aren't cleaned up once the tests completed.

A non-termination failure still represents a possible real hang. Use the process sample and app logs to distinguish startup, crash handling, drain, and SDK shutdown hangs from simulator service problems. The harness does not change crash-recorder behavior or relax the crash/report assertions.
