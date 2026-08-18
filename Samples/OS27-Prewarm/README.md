# xOS 27 app prewarm validation

Focused physical-device harness for [#8129](https://github.com/getsentry/sentry-cocoa/issues/8129).

See [`RESULTS.md`](RESULTS.md) for the recorded test matrix and findings.

## Captured data

- `ActivePrewarm` at an early constructor, Objective-C `+load`, a late constructor, and lifecycle events
- Process start, `main`, app/scene lifecycle, root `viewDidAppear`, and first `CADisplayLink` timestamps
- Whether a debugger was attached
- Xcode, SDK, OS, build label, SDK generation, and standalone-tracing mode
- Serialized Sentry transactions from `beforeSendTransaction`

Reports are stored in `Documents/OS27Prewarm`. File sharing is enabled, so they are also available through Files on the device.

## Prerequisites

- Physical device running iOS 27
- Xcode 26.6 and/or Xcode 27 beta
- Trusted and unlocked device connected to the Mac
- GetSentry (`97JCY7859U`) developer account added in Xcode, or another Apple development team for automatic signing

Do not use Simulator results or a manually injected `ActivePrewarm=1` value as evidence of OS behavior.

## 1. List devices

```bash
./scripts/os-27-prewarm.sh --action devices
```

Use either the device name or identifier in subsequent commands.

## 2. Build and install

The install action deliberately does not launch the app.

### Xcode 26, SDK v9, attached app-start mode

```bash
./scripts/os-27-prewarm.sh \
  --action install \
  --device "DEVICE" \
  --developer-dir /Applications/Xcode.app/Contents/Developer \
  --sdk-generation 9 \
  --standalone false \
  --build-label xcode-26-v9-attached
```

### Xcode 27, SDK v9, attached app-start mode

```bash
./scripts/os-27-prewarm.sh \
  --action install \
  --device "DEVICE" \
  --developer-dir /Applications/Xcode-beta.app/Contents/Developer \
  --sdk-generation 9 \
  --standalone false \
  --build-label xcode-27-v9-attached
```

### Xcode 27, SDK v9, standalone mode

```bash
./scripts/os-27-prewarm.sh \
  --action install \
  --device "DEVICE" \
  --developer-dir /Applications/Xcode-beta.app/Contents/Developer \
  --sdk-generation 9 \
  --standalone true \
  --build-label xcode-27-v9-standalone
```

### Xcode 27, SDK v10

```bash
./scripts/os-27-prewarm.sh \
  --action install \
  --device "DEVICE" \
  --developer-dir /Applications/Xcode-beta.app/Contents/Developer \
  --sdk-generation 10 \
  --build-label xcode-27-v10
```

The harness uses automatic signing with the GetSentry team by default. To use another team, append:

```bash
--development-team TEAM_ID
```

All variants use the same bundle identifier so launch history and the app data container survive an update. Installing another variant replaces the current app; collect each variant before replacing it.

## 3. Run without a debugger

1. Disconnect from the Xcode debugger.
2. Launch **OS27-Prewarm** by tapping its Home Screen icon.
3. Check the in-app `ActivePrewarm` value.
4. Use the app normally over multiple launches.
5. Leave the device locked and charging between launch sessions when possible.

For a useful matrix:

- First launch after installing or rebooting
- Repeated process launches without rebooting
- Naturally predicted launches after the app has accumulated usage history
- Background launches, such as silent push, when available. The app registers after its first display and stores the APNs device token in the `application.didRegisterForRemoteNotifications` event.

> [!WARNING]
> Do not repeatedly force-quit the app while looking for predicted prewarming. User force-quit state can prevent background and anticipated launches. There is no supported deterministic trigger for real prewarming.

A launch with `ActivePrewarm: YES` is the primary result. Confirm that `debuggerAttached` is `false` in its JSON report.

## 4. Simulate the detection path

Run one command to inject `ActivePrewarm=1`, suspend the process for 15 seconds, resume it, and collect the report:

```bash
./scripts/os-27-prewarm.sh \
  --action simulate-prewarm \
  --device "DEVICE"
```

Override the suspension with `--suspend-seconds NUMBER`. This validates Sentry's detection, timing, and serialization path, but it is not evidence of natural OS prewarming.

## 5. Collect and summarize

```bash
./scripts/os-27-prewarm.sh \
  --action collect \
  --device "DEVICE"
```

Collected files go to `.build/os-27-prewarm/results/<timestamp>` and a TSV summary is printed. To summarize an existing directory:

```bash
./scripts/os-27-prewarm.sh \
  --action summarize \
  --input .build/os-27-prewarm/results
```

## 6. Interpret a prewarmed launch

For a valid prewarmed report, verify:

- `activePrewarmDetected` is `true`.
- `early.activePrewarmAtLoad` is `true`, matching Sentry's current detection point.
- `early.debuggerAttached` is `false`.
- `processToEarlyConstructorMs` may contain the suspended prewarm interval.
- `sinceEarlyConstructorContinuousMs` through `firstDisplayLink` does not contain that interval.
- The Sentry transaction reports the launch as prewarmed.
- The Sentry duration starts near module initialization rather than process creation.
- V10 does not emit an implausibly long standalone transaction if detection fails.

The harness records both `viewDidAppear` and the first display-link callback because they represent different launch boundaries.
