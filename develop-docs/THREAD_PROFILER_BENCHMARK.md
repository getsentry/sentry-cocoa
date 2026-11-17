# Thread Profiler Benchmark

**Continuous 50 ms sampling adds measurable CPU cost in this workload.** Across five separate app launches, CPU usage increased **3.75–5.31% relative**, adding **127–187 ms of process CPU time per approximately 10-second measurement arm**. This does not establish whether users would notice a responsiveness change.

## Key facts

| Fact                    | Value                                                                                                              |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Measurement date        | 2026-11-17                                                                                                         |
| Device                  | Physical iPhone 14, iOS 26.7.3                                                                                     |
| Build                   | Release, development-signed, launched without a debugger                                                           |
| Source baseline         | `fedc5e327` plus the uncommitted benchmark implementation                                                          |
| App                     | [ThreadProfilerBenchmark](../TestApps/ThreadProfilerBenchmark)                                                     |
| SDK sampler             | [SentryThreadProfilerBenchmark](../Sources/Swift/Integrations/AppHangTracking/SentryHangTrackingIntegration.swift) |
| Stack capture           | Existing V9 `SentryThreadInspector.getCurrentThreadsWithStackTrace()`                                              |
| Scheduling              | Dispatch-source timer on a serial background queue, 50 ms interval, zero configured leeway                         |
| SDK configuration       | Default options with a DSN, except app hang tracking and session replay disabled                                   |
| Baseline                | SDK enabled, benchmark sampler stopped                                                                             |
| Profiled                | Same SDK configuration and workload, benchmark sampler continuously active during the profiled arm                 |
| Workload                | Animated SwiftUI drawing, scrolling catalog, 60 Hz main-run-loop workload timer                                    |
| Independent invocations | Five sequential app launches, each running five ordered baseline/profiled pairs                                    |
| Total comparisons       | 25 baseline/profiled pairs, excluding the earlier exploratory invocation                                           |
| Per arm                 | 2-second workload warm-up, then approximately 10 seconds of measurement                                            |
| Cooldown                | 1 second after each baseline arm                                                                                   |
| CPU measurement         | Process user + system CPU time across all threads. 100% CPU represents one core                                    |
| Inspector timing        | Date-provider monotonic timestamps around the entire inspector call, including stack construction                  |
| Retained sample data    | Counts and timings only. Stacks discarded each tick                                                                |
| Completion              | All five invocations exited with code 0. Four complete reports explicitly printed `BENCHMARK_STATUS: PASS`         |

## CPU and time per invocation

Each row aggregates five baseline/profiled pairs. Added CPU time estimates the baseline/profiled process CPU difference, not inspector-call elapsed time or main-thread pauses. Per sample = added mean CPU time per arm × five arms ÷ captured samples. Per second uses the nominal 10-second arm duration.

| Invocation | Relative CPU overhead | Added CPU ms / sample | Added CPU ms / second | Added CPU ms / approximately 10-second arm |
| ---------- | --------------------: | --------------------: | --------------------: | -----------------------------------------: |
| 1          |               +3.974% |                 0.672 |                  13.5 |                                        135 |
| 2          |               +3.770% |                 0.632 |                  12.7 |                                        127 |
| 3          |               +4.756% |                 0.806 |                  16.2 |                                        162 |
| 4          |               +3.746% |                 0.656 |                  13.2 |                                        132 |
| 5          |               +5.307% |                 0.930 |                  18.7 |                                        187 |

## Inspector-call timings

Durations are elapsed milliseconds, pooled across the five profiled arms within each invocation. They are **not thread suspension durations**.

| Invocation | Samples | Thread stacks | Frames | Empty thread/stack captures | Total inspector time (ms) |    Mean (ms) |  Median (ms) |     p95 (ms) |     p99 (ms) | Maximum (ms) |
| ---------- | ------: | ------------: | -----: | --------------------------: | ------------------------: | -----------: | -----------: | -----------: | -----------: | -----------: |
| 1          |   1,005 |        11,061 | 97,004 |                           0 |                   965.525 |        0.961 |        0.797 |        1.890 |        2.205 |        2.769 |
| 2          |   1,005 |        11,061 | 93,995 |                           0 |                   961.938 |        0.957 |        0.799 |        1.879 |        2.209 |        2.796 |
| 3          |   1,005 |        11,867 | 89,197 |                           0 |                   936.755 |        0.932 |        0.777 |        1.698 |        2.133 |        2.558 |
| 4          |   1,006 |        11,074 | 89,511 |                Not captured |              Not captured | Not captured | Not captured | Not captured | Not captured | Not captured |
| 5          |   1,005 |        11,063 | 93,834 |                           0 |                   964.691 |        0.960 |        0.810 |        1.908 |        2.240 |        3.019 |

> [!NOTE]
> Invocation 4 completed all pairs and exited with code 0, but `devicectl --console` truncated stdout before the capture-failure count and inspector timings. Missing values are not estimated.

## Main-thread workload timing

These are timer callback intervals, not presented-frame measurements. Deltas use independently rounded benchmark output.

| Invocation | Baseline updates/s | Profiled updates/s | Updates/s delta | Baseline p95 gap (ms) | Profiled p95 gap (ms) | p95 gap delta (ms) | Baseline maximum gap (ms) | Profiled maximum gap (ms) | Maximum gap delta (ms) |
| ---------- | -----------------: | -----------------: | --------------: | --------------------: | --------------------: | -----------------: | ------------------------: | ------------------------: | ---------------------: |
| 1          |             58.490 |             58.533 |          +0.042 |                20.847 |                21.012 |             +0.165 |                    56.815 |                    50.840 |                 -5.975 |
| 2          |             58.794 |             58.409 |          -0.385 |                20.604 |                21.368 |             +0.764 |                    51.975 |                    55.323 |                 +3.348 |
| 3          |             58.138 |             58.435 |          +0.296 |                21.128 |                21.538 |             +0.411 |                    59.032 |                    52.997 |                 -6.035 |
| 4          |             58.453 |             58.863 |          +0.410 |                20.898 |                20.572 |             -0.325 |                    54.271 |                    48.872 |                 -5.399 |
| 5          |             58.388 |             58.433 |          +0.045 |                21.218 |                21.310 |             +0.092 |                    55.770 |                    51.809 |                 -3.961 |

## Interpretation

| Question                                                            | Finding                                                                                                                                                                                                                                                            |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Does an always-active SDK profiler negatively impact performance?   | **It has a measurable CPU cost here.** Every invocation consumed more CPU with 20 Hz all-thread sampling enabled. Mean relative increase across the five invocations: approximately **4.31%**, with approximately **149 ms additional CPU time per 10-second arm** |
| Does the benchmark show a main-thread timing cost?                  | p95 timer gaps increased in four of five invocations, by at most 0.764 ms. Update throughput and maximum gaps changed in mixed directions                                                                                                                          |
| Does this prove users will notice hitches?                          | No. Presented frames, interaction latency, and hitch counts were not measured                                                                                                                                                                                      |
| Can full inspector-call duration be treated as a main-thread pause? | No. It includes work after threads resume, such as stack-object construction                                                                                                                                                                                       |
| Is the profiler free or equivalent to the standalone reference?     | Not free. This experiment does not establish equivalence to the standalone C sampler, which uses different scheduling and reports suspension-window timings                                                                                                        |
| Does this cover a production always-on profiler?                    | Only its snapshot-sampling cost at this cadence. Stack retention, serialization, upload, and hang-event creation are excluded                                                                                                                                      |
| What remains unmeasured?                                            | Memory, battery, thermal state, presented frames, other devices, other sampling cadences, and representative host-app workloads                                                                                                                                    |
| Strength of evidence                                                | One device and one synthetic workload, with baseline always preceding sampling. Repetition shows consistent CPU overhead but does not establish statistical significance or generalize to all apps                                                                 |

## Reproduce

```sh
make build-testapp-ThreadProfilerBenchmark \
  THREAD_PROFILER_DESTINATION='platform=iOS,id=00008110-000914A62213A01E' \
  THREAD_PROFILER_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=BZ362SQ6AB'

xcrun devicectl device install app --device 'iPhone Sentry' \
  .build/thread-profiler-benchmark/Build/Products/Release-iphoneos/ThreadProfilerBenchmark.app

xcrun devicectl device process launch --device 'iPhone Sentry' \
  --console --timeout 180 io.sentry.sample.ThreadProfilerBenchmark -- --benchmark
```

Use your connected device and development team. Repeat the launch command five times sequentially, saving each invocation's output separately.
