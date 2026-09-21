# Thread Inspection Harness

This macOS Swift package tests the C capture path used by the V10 `SentryDefaultThreadInspector`. It compiles the production sources through relative symlinks into `Sources/Sentry`; it does not contain a copy of the implementation and is not part of an SDK release target.

This is a nonfatal inspection path. Fatal reports use KSCrash's own thread capture pipeline.

KSCrash #913 is merged into `develop`, whose report APIs are incompatible with the SDK's 2.6 integration. The SDK and harness therefore pin the compatible backport in `getsentry/KSCrash` at revision `391bf0a9569b6c1aa9df30b3fa4bcabbc0a07e7a`.

## Run the Tests

From the sentry-cocoa worktree root:

```sh
swift test --package-path Tests/ThreadInspectionHarness
swift test --package-path Tests/ThreadInspectionHarness --scratch-path /tmp/thread-inspection-asan --sanitize address
swift test --package-path Tests/ThreadInspectionHarness --scratch-path /tmp/thread-inspection-ubsan --sanitize undefined
swift test --package-path Tests/ThreadInspectionHarness --scratch-path /tmp/thread-inspection-tsan --sanitize thread --filter 'ReservedThreadContractTests|SentryThreadSnapshotTests|SentryThreadInspectionLifecycleTests'
```

Run each command in a fresh process. KSCrash reserved-thread registration and successful SDK installation readiness last for the life of the process.

The TSan selection excludes tests that suspend real threads. TSan runtime synchronization cannot prove that production code is safe while threads are suspended. ASan and UBSan run the deterministic driver and the real Mach adapter. V10 CI runs all four commands when the harness or production snapshot sources change.

To use another SDK-compatible KSCrash checkout, set `KSCRASH_PATH` to its absolute path. The checkout must contain `ksmc_isReservedThread` and remain compatible with the 2.6 report APIs:

```sh
KSCRASH_PATH=/absolute/path/to/KSCrash \
  swift test --package-path Tests/ThreadInspectionHarness
```

Unset `KSCRASH_PATH` for final validation of the pinned dependency. SDK SwiftPM development can instead use `swift package edit KSCrash --path ...`; run `swift package unedit KSCrash` before final validation.

## Run the Pause Benchmark

`ThreadSnapshotBenchmark` measures the production driver and KSCrash adapter while real pthread workers wait at configured recursive stack depths. It writes CSV output and environment details; it does not enforce a hardware-dependent test threshold.

```sh
env -u KSCRASH_PATH swift run -c release \
  --package-path Tests/ThreadInspectionHarness ThreadSnapshotBenchmark \
  | tee /tmp/thread-snapshot-benchmark.csv
```

The default matrix uses 1, 16, 64, and 128 workers at requested depths 0, 64, 256, and 512. Use `--workers`, `--depths`, `--warmups`, and `--iterations` to change it. Run a release build and retain the environment metadata with the CSV.

Before recording results, the benchmark warms the largest requested scenario and then each individual scenario. This reduces one-time unwind-cache and CPU-frequency effects.

The timing backend calls `mach_absolute_time` around existing capture phases:

- `suspend_phase`: before the first successful suspension call through the first unwind.
- `all_suspended`: after the last successful suspension through the first resume. Every acquired target is stopped throughout this interval.
- `first_target_pause`: after the first successful suspension through that target's resume.
- `suspend_resume`: sum of the full suspend and resume phases.
- `stop_window`: after the first successful suspension through the final matching resume. At least one target is stopped throughout this interval.
- `total_capture`: the complete call, including enumeration, preparation, names, and Mach-right cleanup, but excluding result destruction and Swift model conversion.

These measurements describe a one-time all-thread diagnostic. They do not represent the profiler's short per-target sampling interval or a cross-device performance limit.

### Representative Baseline — 2026-09-10

The default command ran on a `Mac16,6` with an Apple M4 Max and 64 GB RAM, on AC power, using macOS 26.6.2 (25G83), an optimized arm64 build, and the pinned KSCrash revision. Five captures of the largest scenario primed the run. Each row then used five warmups and 30 measured captures. Every trial found the requested workers plus the coordinator and balanced every acquired suspension. Percentiles use nearest rank.

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

Depth 512 reaches the 512-frame capacity and reports truncation. Serial unwinding dominates the pause while all targets are stopped. The largest `suspend_resume` P95 in this matrix was 0.109 ms, for 128 workers at depth 512.

## Capture Contract

The implementation is split into four layers:

- `SentryThreadSnapshot.h` defines backend-neutral records and callback contracts.
- `SentryThreadSnapshot.c` owns allocation, process-wide admission, and capture phases.
- `SentryThreadSnapshotKSCrash.c` provides task enumeration, Mach suspension, KSCrash unwind, names, and right cleanup.
- `SentryDefaultThreadInspector+V10.swift` maps completed records to event models after all resume attempts.

A capture proceeds in this order:

1. Enumerate threads and allocate the complete output buffer.
2. Resolve identities, current/main flags, readiness, and reserved-thread membership.
3. Try process-wide suspension admission without waiting.
4. Suspend each eligible remote thread and record every successful suspension.
5. Unwind only the acquired set while it remains stopped, then attempt one matching resume for each target.
6. Release admission, copy names, release enumeration rights, and return the records for model conversion.

The driver allocates nothing and calls only suspension-safe backend callbacks between the first successful suspend and final resume attempt. It has no fixed thread-count cutoff. Individual suspend or unwind failures keep the thread's metadata.

Suspension completes one target at a time, so the snapshot is not atomic. The coordinator, reserved threads, failed targets, newly created threads, and external effects can continue. After the final successful suspension, every acquired target stays stopped until all stacks have been unwound.

Admission is shared with the profiler so two SDK capture coordinators cannot suspend each other. A contending inspector returns metadata and a separately captured current-thread stack without remote stacks. A contending profiler skips that target. Neither path waits for admission.

The caller owns a successful snapshot until `sentryThreadSnapshotDestroy`, which frees and clears it. Enumeration rights remain valid through name lookup and are released before the result returns. Current-thread stacks use the separate KSCrash current-thread provider. Event frames are reversed from captured youngest-to-oldest addresses into oldest-to-youngest order.

## Coverage

The harness covers:

- Deterministic lists of up to 160 records, including current/reserved filtering, main-thread detection, original IDs, and ordering.
- Empty and failed enumeration, allocation failure, size overflow, invalid frame counts, failed suspend/unwind/name operations, and unterminated backend names.
- Independent capture contention, strict suspend/unwind/resume phase order, installation readiness, and one resume attempt for each successful suspension.
- Concurrent readers of KSCrash's single-writer reserved-thread registry.
- Ninety-six live named workers, including an actual reserved thread, complete non-reserved capture, and balanced Mach send rights.
- A thread that exits after enumeration, intercepted Mach failures, and cleanup after both success and allocation failure.
- Stacks beyond the old 100-frame limit, truncation at 512 frames with output guards, and a full 63-byte thread name.

Workers use condition variables and are joined; readiness does not depend on sleeps. The Mach observer resolves the original function pointers before suspension and is linked only into the test bundle.

SDK-level model, ordering, and contention tests live in `Tests/SentryTests/SentryCrash/SentryDefaultThreadInspectorV10Tests.swift`. `Tests/SentryProfilerTests/ObjC/SentryBacktraceTests.mm` verifies profiler behavior while admission is busy. V9 behavior remains covered by `SentryDefaultThreadInspectorTests`.

## Bounds and Lifecycle

V10 follows backend and OS bounds:

- Remote stacks hold up to `KSSC_MAX_STACK_DEPTH`, currently 512 addresses. KSCrash's separate 150-frame overflow classification does not stop capture.
- Thread names use Darwin's 64-byte `thread_extended_info_data_t.pth_name`, including the terminator. Names can contain at most 63 bytes.
- Current-thread capture uses its own KSCrash cursor and storage bound.

The neutral header mirrors the remote-frame and name sizes without importing backend types. Compile-time assertions fail if KSCrash or Darwin changes either bound. V9 keeps its legacy 100-frame and 128-byte limits only in the old inspector path; those limits should leave with V9.

KSCrash publishes reserved threads through a serialized writer: it initializes an immutable array entry, then release-stores the new count. Readers acquire-load the count and inspect only that initialized prefix. The registry has no removal operation. A lookup does not freeze future registration, so SDK remote capture must not overlap crash-handler installation.

The SDK handles that lifecycle as follows:

- `SentryKSCrash.Installer` publishes readiness immediately before and after each installation attempt.
- An inspector that requires crash handling returns metadata without remote stacks until installation succeeds. Current-thread capture remains available.
- An inspector that does not require crash handling may capture before installation, but not while installation is active.
- Readiness is checked after enumeration. An installation starting later can add only threads absent from the retained list.
- Successful readiness lasts for the process. `SentrySDK.close()` does not clear it because KSCrash remains installed.

## Validation Limits

The tests verify driver callback order, ownership, and Mach suspension boundaries. They do not by themselves prove every transitive KSCrash operation is safe while threads are suspended. Source review found that the selected unwind path uses stack or preallocated state, a nonblocking atomic guard, safe memory reads, and fixed-buffer logging.

A failed `thread_resume` has no safe recovery in this diagnostic path. Captured frames remain useful, and the driver continues attempting every remaining resume. The enforced contract is one resume attempt for each suspension acquired by this capture.

The snapshot header is private SDK implementation. Platform builds, packaging, and final symbol/object audits remain SDK-level checks rather than properties proved by this harness.
