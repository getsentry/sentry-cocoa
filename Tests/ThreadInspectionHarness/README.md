# Thread inspection capture-contract harness

A focused macOS SwiftPM package compiling the **same production C sources** as the V10 SDK. Its source/header entries are relative symlinks into `Sources/Sentry/`, not a second implementation. The test package itself is not included in SDK release targets.

KSCrash #913 is merged into `develop`, which is incompatible with the SDK's 2.6 report APIs. The harness and SDK pin the reviewed compatible backport at `supervacuus/KSCrash` revision `391bf0a9569b6c1aa9df30b3fa4bcabbc0a07e7a`.

## Run

From the sentry-cocoa worktree root (no local KSCrash checkout required):

```sh
swift test --package-path Tests/ThreadInspectionHarness
swift test --package-path Tests/ThreadInspectionHarness --scratch-path /tmp/thread-inspection-asan --sanitize address
swift test --package-path Tests/ThreadInspectionHarness --scratch-path /tmp/thread-inspection-ubsan --sanitize undefined
swift test --package-path Tests/ThreadInspectionHarness --scratch-path /tmp/thread-inspection-tsan --sanitize thread --filter 'ReservedThreadContractTests|SentryThreadSnapshotTests|SentryThreadInspectionLifecycleTests'
```

Set `KSCRASH_PATH` to an absolute local package path to use a different SDK-compatible worktree containing `ksmc_isReservedThread`. Run each command in a fresh test process: reserved-thread entries and successful SDK installation readiness have process lifetime.

The TSan selection deliberately excludes actual remote-thread suspension; sanitizer runtime synchronization is not a production suspended-thread safety guarantee. ASan and UBSan cover the real Mach adapter as well as the deterministic driver. The V10 CI workflow runs all four commands for relevant harness and production-source changes. The timing benchmark remains manual and has no CI threshold.

## Stopped-environment pause benchmark

`ThreadSnapshotBenchmark` runs the production driver and KSCrash adapter against real pthread/Mach
workers held at requested recursive stack depths. It reports CSV so runs can be retained and
compared without making hardware-dependent timing an XCTest assertion:

```sh
env -u KSCRASH_PATH swift run -c release \
  --package-path Tests/ThreadInspectionHarness ThreadSnapshotBenchmark \
  | tee /tmp/thread-snapshot-benchmark.csv
```

The default matrix uses 1, 16, 64, and 128 workers at requested depths 0, 64, 256, and
512. Override it with `--workers`, `--depths`, `--warmups`, and `--iterations`. Run an optimized
release build and keep the emitted environment metadata with the CSV. Before measuring, the
benchmark performs the configured number of unmeasured captures at the largest requested scenario
to reduce CPU-frequency and one-time unwind-cache bias, followed by the same number of warmups for
each scenario.

The timing backend adds only `mach_absolute_time` phase observations around the real backend:

- `suspend_phase` starts immediately before the first suspension call that succeeds and ends at the
  first unwind. It includes that first call, all later suspend attempts, and loop bookkeeping.
- `all_suspended` starts when the last successful suspension returns and ends immediately before
  the first resume. Every successfully suspended target remains stopped for this interval, including
  any remaining failed suspend attempts and all unwinds.
- `first_target_pause` spans the return from the first successful target suspension through
  completion of its matching resume.
- `suspend_resume` is the per-capture sum of the complete suspend and resume phases.
- `stop_window` spans the return from the first successful suspension through completion of the
  final matching resume. At least one target is stopped throughout this broader interval.
- `total_capture` includes enumeration, preparation, names, and Mach-right cleanup, but not result
  destruction or Swift/model conversion.

These measurements characterize a one-shot relational diagnostic, not the profiler's per-target
sampling interval. They are a reproducible baseline rather than a cross-device performance limit.
Real applications have heterogeneous stacks and runnable threads, and phone hardware, power,
thermal state, loaded images, and unwind encodings can materially change the results.

### Representative baseline — 2026-09-10

The default command above ran on a `Mac16,6` with an Apple M4 Max and 64 GB RAM, on AC power,
using macOS 26.6.2 (25G83), an optimized arm64 build, and the pinned KSCrash revision. Each row has
five per-scenario warmups followed by 30 measured captures; a five-capture 128-worker/512-depth
prime preceded the matrix. All trials enumerated exactly the workers plus the current coordinator,
suspended every worker, and resumed each one. Percentiles use nearest rank.

| Workers | Requested depth | Mean frames/stack | All suspended P50 (ms) | All suspended P95 (ms) | Stop window P50 (ms) | Stop window P95 (ms) | Total capture P95 (ms) |
| ------: | --------------: | ----------------: | ---------------------: | ---------------------: | -------------------: | -------------------: | ---------------------: |
|       1 |               0 |               6.0 |                  0.134 |                  0.139 |                0.135 |                0.140 |                  0.144 |
|      16 |               0 |               6.0 |                  2.181 |                  2.235 |                2.191 |                2.244 |                  2.257 |
|      64 |               0 |               6.0 |                  8.763 |                  9.283 |                8.802 |                9.340 |                  9.400 |
|     128 |               0 |               6.0 |                 17.577 |                 17.758 |               17.652 |               17.838 |                 17.921 |
|       1 |              64 |              70.0 |                  0.205 |                  0.235 |                0.206 |                0.235 |                  0.240 |
|      16 |              64 |              70.0 |                  3.338 |                  3.416 |                3.348 |                3.425 |                  3.441 |
|      64 |              64 |              70.0 |                 13.387 |                 13.711 |               13.430 |               13.761 |                 13.812 |
|     128 |              64 |              70.0 |                 26.865 |                 27.346 |               26.950 |               27.433 |                 27.512 |
|       1 |             256 |             262.0 |                  0.424 |                  0.453 |                0.424 |                0.453 |                  0.459 |
|      16 |             256 |             262.0 |                  6.802 |                  6.927 |                6.813 |                6.938 |                  6.954 |
|      64 |             256 |             262.0 |                 27.191 |                 27.558 |               27.231 |               27.608 |                 27.665 |
|     128 |             256 |             262.0 |                 54.462 |                 55.257 |               54.545 |               55.348 |                 55.444 |
|       1 |             512 |             512.0 |                  0.698 |                  0.717 |                0.698 |                0.717 |                  0.722 |
|      16 |             512 |             512.0 |                 11.420 |                 11.566 |               11.430 |               11.577 |                 11.592 |
|      64 |             512 |             512.0 |                 45.472 |                 45.888 |               45.516 |               45.936 |                 45.986 |
|     128 |             512 |             512.0 |                 91.016 |                 92.133 |               91.102 |               92.229 |                 92.327 |

Depth 512 reaches the backend's 512-frame capacity and every such worker reports truncation. The
observed pause is dominated by serial unwinding while all acquired targets remain stopped. The
per-capture `suspend_resume` metric includes the first `thread_suspend` call; its largest P95 in this
matrix was 0.109 ms, for 128 workers at depth 512.

## Local upstream-development override

Normal harness and SDK validation uses the pinned published revision. To test another SDK-compatible KSCrash checkout, set `KSCRASH_PATH` for this harness. For SDK SwiftPM development only, use `swift package edit KSCrash --path ...`, then `swift package unedit KSCrash` before final validation. Final Xcode and SwiftPM acceptance checks must use the normal tracked dependency route without editable packages or temporary workspaces.

## What is implemented

- `SentryThreadSnapshot.h`: a backend-independent result with
  - thread identity,
  - original enumeration ordinal,
  - main/current flags,
  - capture status,
  - youngest-to-oldest addresses up to KSCrash's remote-stack bound (currently 512),
  - truncation, and
  - a copied name.
    No Mach/KSCrash/SentryCrash type crosses this boundary.
- `SentryThreadSnapshot.c`:
  - dynamic storage allocated _before_ capture,
  - size checks,
  - all identities, flags, policy, and reserved membership resolved before suspension,
  - nonblocking process-wide admission before the first remote suspension, shared with the SDK
    profiler so independent inspectors and profiler samples cannot suspend each other's callers,
  - tracked stop-the-environment phases: suspend every eligible target, unwind exactly the
    successfully suspended set, then make one balancing resume attempt for that set,
  - metadata retained on individual suspend/unwind failure,
  - a backend hook for deterministic tests, and
  - no 70-thread cutoff
- `SentryThreadSnapshotKSCrash.c`:
  - `task_threads` enumeration,
  - current/reserved filtering in the driver,
  - direct Mach suspend/resume wrappers,
  - `ksbt_captureBacktraceFromSuspendedMachThread` while the eligible environment remains stopped,
  - Mach rights and VM-list cleanup, and
  - names use `THREAD_EXTENDED_INFO` after resumption so an exited thread never becomes a dangling `pthread_t` lookup (lessons learned from Android ART).
- Suspension still completes sequentially, so the snapshot cannot be literally atomic. The current
  inspector, KSCrash-reserved threads, failed targets, and external effects can continue. After the
  final successful suspension, however, all captured targets remain stopped through every unwind,
  minimizing cross-stack time skew for relational diagnostics. Statistical profilers retain their
  separate per-target strategy and hold shared admission for only one target at a time.
- Admission never waits. A contending inspector keeps enumeration metadata and its separately built
  current-thread stack but attempts no remote suspension; a contending profiler skips that target.
  The owner releases admission only after every balancing resume attempt.
- The caller holds the snapshot output until `sentryThreadSnapshotDestroy` (which zeroes it).
- Enumeration rights remain held through name lookup, then are released before output is returned. Names and model conversion never require an expired enumeration right.
- `Sources/Swift/SentryCrash/SentryDefaultThreadInspector+V10.swift` consumes these records after resumption, preserves enumeration-derived event IDs, identifies the actual main thread, and emits it first. Current-thread stacks stay with the existing KSCrash current-thread provider. Plain addresses pass through `SentryStacktraceBuilder` / `SentryCrashStackEntryMapper` without manufacturing legacy cursor entries; the existing frame reversal gives oldest-to-youngest event order.
- The provider protocol is available for debug/test injection and stripped to the concrete provider in release. V9 retains its separate Swift/C compatibility implementation.

## What is covered

- Single-writer reserved-thread registration with four concurrent readers. Single-writer is currently assumed because the reserved threads are set during init.
- A deterministic 160-record list, including current/reserved filtering, main-thread identification away from index zero, and retained original IDs/order.
- Empty/failed enumeration, allocation failure, result-buffer size overflow, and enumeration-only operation.
- Failed target suspension/unwind/name lookup, bounded unterminated names, invalid backend frame counts, and address/truncation propagation.
- Deterministic independent capture ownership: while one driver is in its suspension phase, a
  contender performs zero suspend/unwind/resume callbacks, retains metadata, and can acquire only
  after the owner has attempted every resume.
- 96 live named worker threads, with an actually registered reserved worker; all non-reserved workers have frames.
- Real send-right reference balance on success and allocation failure, plus cleanup of a retained dead name after thread exit.
- Intercepted Mach suspend/resume/state-read calls: current/reserved threads are not suspended,
  many eligible targets are simultaneously stopped before the first unwind, suspend failure causes
  no resume call for that target, state-read failure still causes one balancing resume attempt, and
  every successful suspension receives one resume attempt.
- A live 150-deep stack retained beyond the old 100-frame limit, plus a deeper stack truncated at KSCrash's 512-frame bound with guard values around the output array.
- A live thread name filling the OS field (63 name bytes plus the terminator), preserved in full.
- Installation starting during enumeration: policy must be checked afterward and must keep metadata without suspending.
- Initial/failed/successful/repeated installation readiness, including a disabled-crash inspector observing another lifecycle's active installation.

SDK model/order/concurrency tests live in `Tests/SentryTests/SentryCrash/SentryDefaultThreadInspectorV10Tests.swift`; they include two distinct system-backed inspectors falling back under busy process admission. `Tests/SentryProfilerTests/SentryBacktraceTests.mm` verifies that the real profiler enumerator skips a live worker while admission is busy. Legacy behavior stays covered by `SentryDefaultThreadInspectorTests` in V9.

Workers use condition-variable handshakes and are joined; there are no sleep-based readiness assumptions. The Mach observer is test-bundle-only and resolves its original function pointers before suspension.

## Capture bounds

V10 follows the backend's bounds, not independently chosen SDK limits:

- Remote stacks: `KSBacktrace.c` clamps the requested capacity to `KSSC_MAX_STACK_DEPTH`, currently **512**. This is distinct from the **150**-frame stack-overflow classification threshold, which does not stop the walk.
- Names: Darwin's `thread_extended_info_data_t.pth_name` is **64 bytes**, including the terminator. `pthread_setname_np` writes to the kernel first; XNU rejects names longer than 63 bytes with `ENAMETOOLONG` rather than truncating them. The pthread-local cache is updated only on success and has the same size, so there is no hidden longer pthread name. The prototype retains the entire field rather than retaining the old 128-byte scratch buffer.
- Current-thread stacks: the existing SDK provider follows KSCrash's self-thread cursor and its own internal storage bound. Do not impose the remote-stack capacity on that different backend path.

The neutral header mirrors the remote-frame/name capacities without importing backend types. Each constant's comment records its source and semantics, including the separate overflow classification threshold and name-setter failure behavior. Compile-time assertions in the adapter require equality with KSCrash and the OS, so an upstream change cannot silently leave a stale SDK limit. Result storage remains allocated before any suspension.

The old 100-frame value was added to the SentryCrash machine-context header with app-hang tracking (#1906); 128 was the old inspector's name-buffer size, carried into the Swift conversion. Neither is the current KSCrash/OS bound. **V9-only compatibility / remove after V9 retirement:** those limits remain confined to the old Swift/C inspector implementation, now explicitly marked for removal with V9. They are not shared V10 limits.

## Reserved-thread contract and lifecycle

The merged KSCrash query uses the minimal single-writer publication protocol:

1. Read the atomic count with relaxed ordering in the serialized writer.
2. Initialize the next immutable array entry.
3. Release-store the new count.
4. Readers acquire-load the count once and search only that initialized prefix.

The observed production writer is `startNewExceptionHandler` in `KSCrashMonitor_MachException.c`. The two registrations happen sequentially inside a CAS-guarded installation. Existing suspend/resume operations already read the registry; the public query adds concurrent readers, not a demonstrated need for multiple writers. Capacity and registration behavior remain unchanged. Registration callers must serialize themselves; lookup does not block them.

An initial experiment deliberately inserted registration between query and capture and confirmed that the old query result could become stale. That is a membership-query limitation, **not** evidence requiring a new upstream capture-admission protocol. The intentionally failing experiment was removed from the maintained suite. No multiple-writer support, registry-removal API, or higher-level enumeration API is proposed here.

The implemented SDK startup policy accounts for the hub being published before `installIntegrations`:

- The serialized `SentryKSCrash.Installer` brackets the real install with C readiness notifications, including error returns. It does not expose its plain Swift `installed` property to the capture path.
- An inspector requiring crash handling enumerates without remote stacks until successful install. A failed install keeps this conservative fallback until a successful retry. Current-thread stacks remain available.
- Disabled-crash and pre-options inspectors can capture without installing a crash handler, but also respect an installation currently in progress. Checking readiness **after enumeration** matters: an installation starting afterward can only create new infrastructure threads absent from the retained list.
- Once published successfully, readiness has process lifetime. `close()` does not reset it, and redundant install attempts cannot revoke it because KSCrash remains installed.
- The check never waits on the installer and runs before any target suspension.

## Limits of this validation

Consumer cleanup for #8799 is implemented: V10 uses the new inspector/provider and plain-address mapping, V9 retains its compatibility implementation, and the ten-Tool V10 allowlist is empty. The neutral header is private SDK implementation, not public API.

Tests check the driver's callback ordering and Mach suspension boundaries, not every transitive allocation/lock/Objective-C entry inside the unwinder. Source inspection found the suspended KSBacktrace path uses stack/preallocated state and a nonblocking atomic guard; the default KSCrash C logger uses its fixed buffer and `write`, not the optional stdio mode. A real resume failure is not safely recoverable, so the enforced contract is one resume attempt per acquired suspension. Full SDK platform, packaging, object, and symbol audits are recorded in the project handoff rather than proved by this harness.
