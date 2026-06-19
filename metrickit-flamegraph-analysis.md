# How MetricKit Events Are Captured and Displayed as Flamegraphs

## Capture (SDK side)

The Cocoa SDK subscribes to Apple's MetricKit via `SentryMXManager` (implements `MXMetricManagerSubscriber`). When iOS delivers an `MXDiagnosticPayload`, it contains diagnostics like `MXHangDiagnostic`, `MXCrashDiagnostic`, etc. Each diagnostic carries an `MXCallStackTree` — a **tree-shaped** JSON structure where each frame has a `subFrames` array and a `sampleCount`.

### Key Files

| File                                                               | Role                                                             |
| ------------------------------------------------------------------ | ---------------------------------------------------------------- |
| `Sources/Swift/Core/MetricKit/SentryMetricKitIntegration.swift`    | Integration registration and initialization                      |
| `Sources/Swift/Core/MetricKit/SentryMXManager.swift`               | `MXMetricManagerSubscriber` — receives and processes diagnostics |
| `Sources/Swift/Core/MetricKit/SentryMXCallStackTree.swift`         | JSON deserialization model for `MXCallStackTree`                 |
| `Sources/Swift/Core/MetricKit/SentryMXCallStackTree+Parsing.swift` | Tree parsing, flattening, and conversion to Sentry frames        |
| `Sources/Swift/Core/MetricKit/MXSample.swift`                      | Internal sample format used during tree-to-linear conversion     |

### Diagnostic Types

| Diagnostic                       | Mechanism Type            | Level             | Extra Data                         |
| -------------------------------- | ------------------------- | ----------------- | ---------------------------------- |
| `MXCrashDiagnostic`              | `MXCrashDiagnostic`       | error (unhandled) | exception type, code, signal       |
| `MXHangDiagnostic`               | `mx_hang_diagnostic`      | warning (handled) | `hangDuration`                     |
| `MXCPUExceptionDiagnostic`       | `mx_cpu_exception`        | warning (handled) | `totalCPUTime`, `totalSampledTime` |
| `MXDiskWriteExceptionDiagnostic` | `mx_disk_write_exception` | warning (handled) | `totalWritesCaused`                |

## The Special Data Format

There is a special format, and it's **different from regular stack traces**. The SDK uses two conversion strategies depending on the diagnostic type.

### MXCallStackTree JSON Structure

Apple delivers call stacks as a tree:

```json
{
  "callStacks": [
    {
      "threadAttributed": true,
      "callStackRootFrames": [
        {
          "binaryUUID": "9E8D8DE6-EEC1-3199-8720-9ED68EE3F967",
          "offsetIntoBinaryTextSegment": 414732,
          "sampleCount": 3,
          "binaryName": "Sentry",
          "address": 4312798220,
          "subFrames": [
            {
              "binaryUUID": "CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF",
              "offsetIntoBinaryTextSegment": 46380,
              "sampleCount": 1,
              "binaryName": "iOS-Swift",
              "address": 4310988076,
              "subFrames": []
            }
          ]
        }
      ]
    }
  ],
  "callStackPerThread": true
}
```

### Strategy 1: Flattened Tree (for `MXHangDiagnostic`)

The full tree is preserved by flattening it into an array where each `SentryFrame` carries two extra fields:

- **`parent_index`** — index of the parent frame in the flat array (-1 for roots)
- **`sample_count`** — number of samples recorded at that frame

This is what enables flamegraph rendering: the frontend reconstructs the tree from `parent_index` relationships and sizes each node by `sample_count`.

**Example:**

```
Tree:        F1(sampleCount:3)
               ├─ F2(sampleCount:3)
               │   ├─ F3(sampleCount:1)
               │   └─ F4(sampleCount:2)

Flattened:   Frame[0]: F1, parent_index:-1, sample_count:3
             Frame[1]: F2, parent_index:0,  sample_count:3
             Frame[2]: F3, parent_index:1,  sample_count:1
             Frame[3]: F4, parent_index:1,  sample_count:2
```

Key code: `SentryMXCallStackTree+Parsing.swift` → `flattenedBacktrace()`.

### Strategy 2: Most-Sampled Path (for crashes, CPU, disk exceptions)

The tree is collapsed to a single linear stack trace — the most frequently sampled path through the tree. No tree metadata is preserved. These render as normal stack traces, not flamegraphs.

Key code: `SentryMXCallStackTree+Parsing.swift` → `sentryMXBacktrace()`.

## Frame Properties

All MetricKit frames include:

```
package          = binaryName           (e.g., "Sentry", "iOS-Swift")
instructionAddress = hex(address)       (e.g., "0x0000000100000001")
imageAddress     = hex(address - offset) (base address for symbolication)
```

Flattened tree frames (hangs) additionally include:

```
parent_index     = index of parent frame in the flat list (NSNumber, -1 for roots)
sample_count     = number of samples at this frame (NSNumber)
```

## Event Structure

MetricKit events are created with:

- `event.level` = `.warning` (handled) or `.error` (unhandled crash)
- `event.timestamp` = `payload.timeStampBegin` (when the diagnostic occurred, not now)
- `event.exceptions[0]` with type, value, mechanism, and stacktrace
- `event.threads` — array of `SentryThread` objects from parsing
- `event.debugMeta` — binary UUIDs and addresses for symbolication
- `mechanism.synthetic = true` on all MetricKit events
- Optional raw `MXDiagnosticPayload.json` attachment (if `enableMetricKitRawPayload` is enabled)

## Data Flow

```
Apple MetricKit
    ↓
MXDiagnosticPayload (MXHangDiagnostic, MXCrashDiagnostic, etc.)
    ↓
MXCallStackTree.jsonRepresentation() → JSON bytes
    ↓
SentryMXCallStackTree.from(data:) → JSONDecoder
    ↓
├─→ [crashes/CPU/disk]  sentryMXBacktrace()   → most-sampled linear stack
└─→ [hangs]             flattenedBacktrace()  → full tree with parent_index + sample_count
    ↓
SentryThread[] with Frame[] + DebugMeta[]
    ↓
Event with Exception + threads + debugMeta
    ↓
SentrySDK.capture(event:)
```

## Comparison with sentry-java ANR Flamegraphs

The Java SDK takes a fundamentally different approach for ANR flamegraphs:

| Aspect                  | Cocoa (MetricKit)                                             | Java (ANR)                                                                      |
| ----------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **Source**              | Apple delivers tree-shaped `MXCallStackTree`                  | SDK polls main thread every 66ms                                                |
| **Format**              | Tree flattened with `parent_index` + `sample_count` per frame | Continuous profiling format: deduplicated frames + stacks + timestamped samples |
| **Attached as**         | Part of the event's `threads[].stacktrace.frames[]`           | Separate `ProfileChunk` linked via `ProfileContext`                             |
| **Tree reconstruction** | Via `parent_index` references                                 | Via sample → stack → frame index chain                                          |
| **Mechanism types**     | `mx_hang_diagnostic`, `MXCrashDiagnostic`, etc.               | `anr_foreground`, `anr_background`                                              |

The Cocoa SDK embeds the flamegraph data **inline in the event's frames**, while Java sends it as a **separate profile chunk** using the standard continuous profiling protocol.

### Java ANR Profile Structure

```
SentryProfile
  ├─ frames: List<SentryStackFrame>      (deduplicated frame definitions)
  ├─ stacks: List<List<Integer>>          (frame index sequences, deduplicated)
  ├─ samples: List<SentrySample>          (timestamp + stackId + threadId)
  └─ threadMetadata: Map<String, ...>     (thread name, priority)
```

Key files:

- `sentry-android-core/.../anr/AnrProfilingIntegration.java` — polls main thread at 66ms intervals
- `sentry-android-core/.../anr/StackTraceConverter.java` — converts stack traces to `SentryProfile`
- `sentry-android-core/.../ApplicationExitInfoEventProcessor.java` — attaches profile to ANR event

## Display

Sentry's frontend reconstructs the tree from either format and renders it as a flamegraph on the issue details page. For MetricKit hangs, it walks the `parent_index` chain to rebuild the call tree and uses `sample_count` to determine the width of each node.

## Configuration

```swift
SentrySDK.start { options in
    options.enableMetricKit = true              // default: false
    options.enableMetricKitRawPayload = false   // attach raw JSON payload
}
```

Available on iOS 15+, macOS 12+, visionOS (Cocoa SDK 8.14.0+).
