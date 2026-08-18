# xOS 27 app prewarm validation results

## Test environment

- Date: 2026-08-18
- Device: iPhone 16 Pro (`iPhone17,1`)
- Device OS: iOS 27.0 (`24A5418b`)
- Debugger attached: no
- Bundle identifier: `io.sentry.sample.iOS-Swift`

## Results

| Build                                  | Launch | Prewarmed | Process → `didFinish` | Process → first display link | Sentry duration | Comparison                       | Reported                       |
| -------------------------------------- | ------ | --------: | --------------------: | ---------------------------: | --------------: | -------------------------------- | ------------------------------ |
| Xcode 26.6, SDK 26.5, V9 attached      | Cold   |        No |            252.323 ms |                   280.500 ms |      280.312 ms | Sentry vs display: -0.188 ms     | Yes, attached to `ui.load`     |
| Xcode 26.6, SDK 26.5, V9 attached      | Warm   |        No |            169.225 ms |                   221.464 ms |      220.631 ms | Sentry vs display: -0.833 ms     | Yes, attached to `ui.load`     |
| Xcode 27 beta, SDK 27.0, V9 attached   | Cold   |        No |            136.396 ms |                   162.871 ms |      162.763 ms | Sentry vs display: -0.108 ms     | No app-start data on `ui.load` |
| Xcode 27 beta, SDK 27.0, V9 attached   | Warm   |        No |            143.305 ms |                   190.989 ms |      190.008 ms | Sentry vs display: -0.981 ms     | No app-start data on `ui.load` |
| Xcode 27 beta, SDK 27.0, V9 standalone | Cold   |        No |            112.316 ms |                   152.920 ms |      112.407 ms | Sentry vs `didFinish`: +0.091 ms | Yes, standalone `app.start`    |
| Xcode 27 beta, SDK 27.0, V10           | Cold   |        No |             94.286 ms |                   129.279 ms |       94.375 ms | Sentry vs `didFinish`: +0.089 ms | Yes, standalone `app.start`    |
| Xcode 27 beta, SDK 27.0, V10           | Warm   |        No |             63.592 ms |                    92.719 ms |       63.676 ms | Sentry vs `didFinish`: +0.084 ms | Yes, standalone `app.start`    |

## Controlled simulation

| Build                        | Suspension | `ActivePrewarm` | Process → `main` | Process → `didFinish` | Sentry duration | Excluded before module init |
| ---------------------------- | ---------: | --------------: | ---------------: | --------------------: | --------------: | --------------------------: |
| Xcode 27 beta, SDK 27.0, V10 | 15 seconds |        Injected |    15,664.844 ms |         15,724.575 ms |      128.883 ms |               15,595.692 ms |

The simulation used `devicectl --start-stopped` and injected `ActivePrewarm=1`; it did not trigger natural OS prewarming. The early constructor, Objective-C `+load`, `main`, and launch callbacks observed the environment value, while it had been cleared by `viewDidAppear`. No debugger was attached. Sentry correctly started the transaction at module initialization, excluded the artificial suspended interval, set `app.vitals.start.prewarmed` to `true`, and emitted only the UIKit and application initialization spans that occurred after the adjusted start timestamp.

## Launch reports

| Build and launch                 | Launch ID                              | Sentry trace                                                                                 |
| -------------------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------- |
| Xcode 26, V9 attached, cold      | `3e24ae8a-c19f-4c35-b606-ad36b4f3bded` | [trace](https://sentry-sdks.sentry.io/explore/traces/trace/1675b0db88a8469b8f8bdcc7e36baa9a) |
| Xcode 26, V9 attached, warm      | `0f9e2ae7-e295-40ed-8951-1bf608a7c652` | [trace](https://sentry-sdks.sentry.io/explore/traces/trace/9de7234c5e0f4493a48b8a2517ff96a8) |
| Xcode 27, V9 attached, cold      | `a7ad8d7f-5ad4-4fe0-8ae1-5842af61618b` | [trace](https://sentry-sdks.sentry.io/explore/traces/trace/2bd76390929e4a22b1bc1d8f1c5dce77) |
| Xcode 27, V9 attached, warm      | `ff69f5e8-2241-4cee-b6eb-367ce0369f5c` | [trace](https://sentry-sdks.sentry.io/explore/traces/trace/165ad891f4444741919030bf417413db) |
| Xcode 27, V9 standalone, cold    | `7ff2e7c5-0e8d-4aab-9203-f9ff7071e9b6` | [trace](https://sentry-sdks.sentry.io/explore/traces/trace/8b36a23efe4147b28262382da928d3c1) |
| Xcode 27, V10, cold              | `5b09c77e-f696-4cf9-9856-fce614cf4689` | [trace](https://sentry-sdks.sentry.io/explore/traces/trace/d6648a597c3845a9ad1fe26e80d8f318) |
| Xcode 27, V10, warm              | `91a9b357-05d4-4c19-a2fe-3e7ad60d6bb2` | [trace](https://sentry-sdks.sentry.io/explore/traces/trace/fb18cec459014f5aa041b8ebed49dcc3) |
| Xcode 27, V10, simulated prewarm | `8bf4d47d-2044-4b9b-a3ba-950a4ec65864` | [trace](https://sentry-sdks.sentry.io/explore/traces/trace/4daa4f69147a4f27b00347cbe90b5df2) |

Raw reports are collected under `.build/os-27-prewarm/results/`. They are intentionally not tracked because they contain device-specific metadata and may contain an APNs device token.

## Findings

### Ordinary cold and warm measurements

- No launch reported `ActivePrewarm` at the early constructor, Objective-C `+load`, late constructor, or lifecycle stages.
- For all attached-mode launches, Sentry started at the process-start timestamp.
- Sentry's first-display durations were within 1 ms of the independent probe.
- The Xcode 26 cold and warm launches correctly attached app-start measurements and spans to the first `ui.load` transaction.

### Attached-mode ordering race reproduced with Xcode 27

- The Xcode 27 cold `ui.load` transaction finished 0.473 ms before Sentry created the app-start measurement.
- The Xcode 27 warm `ui.load` transaction finished 0.550 ms before Sentry created the app-start measurement.
- Both internal app-start measurements were accurate, but neither was attached to the first `ui.load` transaction.
- In the Xcode 26 cold and warm runs, the measurement existed 8.583 ms and 8.385 ms, respectively, before the transaction finished, so both attached successfully.
- Unless another eligible `ui.load` transaction starts within the provider's five-second window, the app-start measurement is not reported.
- This is an inherent attached-mode race and can occur with older toolchains as well. These four runs show that the tested Xcode 27 build consistently exposed it while the tested Xcode 26 build did not; they do not establish that Xcode 27 introduced it.

### Standalone reporting

- V9 standalone reporting was explicitly opted into with `enableStandaloneAppStartTracing = true`; it produced a complete `app.start` transaction and avoided the attached-mode race.
- The standalone endpoint is `didFinishLaunching`, not first display.
- In the V9 cold standalone run, 40.604 ms elapsed between `didFinishLaunching` and the probe's first display-link callback; this time is intentionally excluded from the standalone measurement.
- V10 also produced a complete `app.start` transaction. Its 94.375 ms measurement was within 0.089 ms of the probe's `didFinishLaunching` boundary, and its spans summed to the complete measurement.
- The V10 cold run excluded 34.993 ms between `didFinishLaunching` and the probe's first display-link callback.
- The V10 warm run produced a complete `app.start` transaction. Its 63.676 ms measurement was within 0.084 ms of the probe's `didFinishLaunching` boundary, and its spans summed to the complete measurement within timestamp precision.
- The V10 warm run excluded 29.127 ms between `didFinishLaunching` and the probe's first display-link callback.

## Conclusion

### Confirmed known limitation of V9 attached mode

V9's default attached mode has an inherent reporting race that is already documented in `SentryTracer`. In both tested Xcode 27 cold and warm launches, the initial `ui.load` transaction finished about 0.5 ms before Sentry created the app-start measurement. The internal measurement was accurate, but the first transaction contained no app-start measurement, context, or spans. If no later eligible `ui.load` transaction starts within five seconds, that launch's app-start data is not reported.

The race can also occur with Xcode 26; it simply did not occur in either sampled Xcode 26 run. Avoiding this race is a stated reason for standalone app-start tracking. V9's explicitly opted-in standalone mode and V10 avoid it by passing the measurement directly to a dedicated `app.start` transaction at `didFinishLaunching`. Attached mode is the V9 default; V10 always uses standalone reporting without an opt-in.

### Confirmed working behavior

- Ordinary cold and warm classification was correct in every tested configuration.
- Attached first-display measurements and standalone `didFinishLaunching` measurements matched the independent probe within 1 ms.
- V9 standalone and V10 emitted complete app-start transactions with correctly partitioned spans.

### Scope limitation

Natural scheduler-driven prewarming did not occur, but verifying when or whether the OS supplies `ActivePrewarm` is outside the SDK acceptance target. The controlled physical-device test verifies the required conditional behavior: when `ActivePrewarm=1` is present on iOS 27, Sentry detects it, adjusts the timestamp and duration, builds the expected spans, and serializes the prewarmed attribute correctly.

## Validation status

### Issue scope

- [x] Xcode 26, SDK V9 attached, cold and warm
- [x] Xcode 27, SDK V9 attached, cold and warm
- [x] Xcode 27, SDK V9 standalone, cold
- [x] Xcode 27, SDK V10, cold and warm
- [x] V10 prewarm detection, timing, spans, and serialization when `ActivePrewarm=1`

Natural scheduler-driven prewarming was not tested because there is no supported deterministic trigger. This does not block validating Sentry's behavior when the OS supplies the prewarm indicator.

Performance values should not be used as an Xcode 26 versus Xcode 27 speed benchmark. The runs primarily validate classification, timing boundaries, and reporting behavior; caches and device state were not controlled as a benchmark.
