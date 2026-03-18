# SentryObjC XCFramework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone `SentryObjC.xcframework` with pure Objective-C headers for consumers without Clang modules.

**Architecture:** Three-tier wrapper (SentryObjC → SentryObjCBridge → Sentry SDK) compiled into a single framework. Public headers use same type names as main SDK (e.g., `SentryOptions`, `SentrySDK`), implemented as pure ObjC.

**Tech Stack:** Objective-C, Swift, Xcode, xcframework build scripts, Ruby (xcodeproj gem)

**Spec:** `docs/superpowers/specs/2026-03-18-sentryobjc-xcframework-design.md`

---

## File Structure

### Files to Rename (Header Naming Convention)

| Current Path                                                  | New Path                                                  |
| ------------------------------------------------------------- | --------------------------------------------------------- |
| `Sources/SentryObjC/Public/SentryObjCSDK.h`                   | `Sources/SentryObjC/Public/SentrySDK.h`                   |
| `Sources/SentryObjC/Public/SentryObjCUser.h`                  | `Sources/SentryObjC/Public/SentryUser.h`                  |
| `Sources/SentryObjC/Public/SentryObjCOptions.h`               | `Sources/SentryObjC/Public/SentryOptions.h`               |
| `Sources/SentryObjC/Public/SentryObjCBreadcrumb.h`            | `Sources/SentryObjC/Public/SentryBreadcrumb.h`            |
| `Sources/SentryObjC/Public/SentryObjCScope.h`                 | `Sources/SentryObjC/Public/SentryScope.h`                 |
| `Sources/SentryObjC/Public/SentryObjCEvent.h`                 | `Sources/SentryObjC/Public/SentryEvent.h`                 |
| `Sources/SentryObjC/Public/SentryObjCId.h`                    | `Sources/SentryObjC/Public/SentryId.h`                    |
| `Sources/SentryObjC/Public/SentryObjCLevel.h`                 | `Sources/SentryObjC/Public/SentryLevel.h`                 |
| `Sources/SentryObjC/Public/SentryObjCGeo.h`                   | `Sources/SentryObjC/Public/SentryGeo.h`                   |
| `Sources/SentryObjC/Public/SentryObjCAttachment.h`            | `Sources/SentryObjC/Public/SentryAttachment.h`            |
| `Sources/SentryObjC/Public/SentryObjCException.h`             | `Sources/SentryObjC/Public/SentryException.h`             |
| `Sources/SentryObjC/Public/SentryObjCFrame.h`                 | `Sources/SentryObjC/Public/SentryFrame.h`                 |
| `Sources/SentryObjC/Public/SentryObjCStacktrace.h`            | `Sources/SentryObjC/Public/SentryStacktrace.h`            |
| `Sources/SentryObjC/Public/SentryObjCThread.h`                | `Sources/SentryObjC/Public/SentryThread.h`                |
| `Sources/SentryObjC/Public/SentryObjCMechanism.h`             | `Sources/SentryObjC/Public/SentryMechanism.h`             |
| `Sources/SentryObjC/Public/SentryObjCMechanismContext.h`      | `Sources/SentryObjC/Public/SentryMechanismContext.h`      |
| `Sources/SentryObjC/Public/SentryObjCMessage.h`               | `Sources/SentryObjC/Public/SentryMessage.h`               |
| `Sources/SentryObjC/Public/SentryObjCRequest.h`               | `Sources/SentryObjC/Public/SentryRequest.h`               |
| `Sources/SentryObjC/Public/SentryObjCDebugMeta.h`             | `Sources/SentryObjC/Public/SentryDebugMeta.h`             |
| `Sources/SentryObjC/Public/SentryObjCNSError.h`               | `Sources/SentryObjC/Public/SentryNSError.h`               |
| `Sources/SentryObjC/Public/SentryObjCSpanId.h`                | `Sources/SentryObjC/Public/SentrySpanId.h`                |
| `Sources/SentryObjC/Public/SentryObjCSpanContext.h`           | `Sources/SentryObjC/Public/SentrySpanContext.h`           |
| `Sources/SentryObjC/Public/SentryObjCSpanProtocol.h`          | `Sources/SentryObjC/Public/SentrySpan.h`                  |
| `Sources/SentryObjC/Public/SentryObjCSpanStatus.h`            | `Sources/SentryObjC/Public/SentrySpanStatus.h`            |
| `Sources/SentryObjC/Public/SentryObjCTraceContext.h`          | `Sources/SentryObjC/Public/SentryTraceContext.h`          |
| `Sources/SentryObjC/Public/SentryObjCTraceHeader.h`           | `Sources/SentryObjC/Public/SentryTraceHeader.h`           |
| `Sources/SentryObjC/Public/SentryObjCTransactionContext.h`    | `Sources/SentryObjC/Public/SentryTransactionContext.h`    |
| `Sources/SentryObjC/Public/SentryObjCTransactionNameSource.h` | `Sources/SentryObjC/Public/SentryTransactionNameSource.h` |
| `Sources/SentryObjC/Public/SentryObjCSamplingContext.h`       | `Sources/SentryObjC/Public/SentrySamplingContext.h`       |
| `Sources/SentryObjC/Public/SentryObjCSampleDecision.h`        | `Sources/SentryObjC/Public/SentrySampleDecision.h`        |
| `Sources/SentryObjC/Public/SentryObjCBaggage.h`               | `Sources/SentryObjC/Public/SentryBaggage.h`               |
| `Sources/SentryObjC/Public/SentryObjCAppStartMeasurement.h`   | `Sources/SentryObjC/Public/SentryAppStartMeasurement.h`   |
| `Sources/SentryObjC/Public/SentryObjCReplayApi.h`             | `Sources/SentryObjC/Public/SentryReplayApi.h`             |
| `Sources/SentryObjC/Public/SentryObjCReplayOptions.h`         | `Sources/SentryObjC/Public/SentryReplayOptions.h`         |
| `Sources/SentryObjC/Public/SentryObjCHttpStatusCodeRange.h`   | `Sources/SentryObjC/Public/SentryHttpStatusCodeRange.h`   |
| `Sources/SentryObjC/Public/SentryObjCMeasurementUnit.h`       | `Sources/SentryObjC/Public/SentryMeasurementUnit.h`       |
| `Sources/SentryObjC/Public/SentryObjCLogger.h`                | `Sources/SentryObjC/Public/SentryLogger.h`                |
| `Sources/SentryObjC/Public/SentryObjCError.h`                 | `Sources/SentryObjC/Public/SentryError.h`                 |
| `Sources/SentryObjC/Public/SentryObjCSerializable.h`          | `Sources/SentryObjC/Public/SentrySerializable.h`          |
| `Sources/SentryObjC/Public/SentryObjCDefines.h`               | `Sources/SentryObjC/Public/SentryDefines.h`               |
| `Sources/SentryObjC/Public/SentryObjCAttributeContent.h`      | `Sources/SentryObjC/Public/SentryAttributeContent.h`      |
| `Sources/SentryObjC/Public/SentryObjCMetric.h`                | `Sources/SentryObjC/Public/SentryMetric.h`                |
| `Sources/SentryObjC/Public/SentryObjCMetricValue.h`           | `Sources/SentryObjC/Public/SentryMetricValue.h`           |
| `Sources/SentryObjC/Public/SentryObjCMetricsApi.h`            | `Sources/SentryObjC/Public/SentryMetricsApi.h`            |
| `Sources/SentryObjC/Public/SentryObjCRedactRegionType.h`      | `Sources/SentryObjC/Public/SentryRedactRegionType.h`      |
| `Sources/SentryObjC/Public/SentryObjCUnit.h`                  | `Sources/SentryObjC/Public/SentryUnit.h`                  |
| `Sources/SentryObjC/Public/SentryObjC.h`                      | Keep as `SentryObjC.h` (umbrella)                         |

### Files to Modify

| File                                         | Changes                                                           |
| -------------------------------------------- | ----------------------------------------------------------------- |
| `Sources/SentryObjC/Public/SentryObjC.h`     | Update all imports to use new names                               |
| `Sources/SentryObjC/Public/module.modulemap` | Already correct (`framework module SentryObjC`)                   |
| `scripts/add-sentryobjc-target.rb`           | Add SentryObjCBridge sources, link Sentry target                  |
| `scripts/build-xcframework-local.sh`         | Add SentryObjC variant                                            |
| `Makefile`                                   | Already has `build-sentryobjc` and `build-sentryobjc-xcframework` |
| `Package.swift`                              | Update SentryObjC target source paths after renames               |

### Files to Create

| File | Purpose                                       |
| ---- | --------------------------------------------- |
| None | All infrastructure exists, just needs updates |

---

## Phase 1: Header Renames

### Task 1: Rename Core Type Headers

**Files:**

- Rename: `Sources/SentryObjC/Public/SentryObjCSDK.h` → `SentrySDK.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCOptions.h` → `SentryOptions.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCScope.h` → `SentryScope.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCEvent.h` → `SentryEvent.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCId.h` → `SentryId.h`

- [ ] **Step 1: Rename SentryObjCSDK.h**

```bash
git mv Sources/SentryObjC/Public/SentryObjCSDK.h Sources/SentryObjC/Public/SentrySDK.h
```

- [ ] **Step 2: Rename SentryObjCOptions.h**

```bash
git mv Sources/SentryObjC/Public/SentryObjCOptions.h Sources/SentryObjC/Public/SentryOptions.h
```

- [ ] **Step 3: Rename SentryObjCScope.h**

```bash
git mv Sources/SentryObjC/Public/SentryObjCScope.h Sources/SentryObjC/Public/SentryScope.h
```

- [ ] **Step 4: Rename SentryObjCEvent.h**

```bash
git mv Sources/SentryObjC/Public/SentryObjCEvent.h Sources/SentryObjC/Public/SentryEvent.h
```

- [ ] **Step 5: Rename SentryObjCId.h**

```bash
git mv Sources/SentryObjC/Public/SentryObjCId.h Sources/SentryObjC/Public/SentryId.h
```

- [ ] **Step 6: Commit core type renames**

```bash
git add -A
git commit -m "ref: rename SentryObjC core headers to match SDK naming"
```

---

### Task 2: Rename User and Context Headers

**Files:**

- Rename: `Sources/SentryObjC/Public/SentryObjCUser.h` → `SentryUser.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCGeo.h` → `SentryGeo.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCBreadcrumb.h` → `SentryBreadcrumb.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCAttachment.h` → `SentryAttachment.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCLevel.h` → `SentryLevel.h`

- [ ] **Step 1: Rename user-related headers**

```bash
git mv Sources/SentryObjC/Public/SentryObjCUser.h Sources/SentryObjC/Public/SentryUser.h
git mv Sources/SentryObjC/Public/SentryObjCGeo.h Sources/SentryObjC/Public/SentryGeo.h
git mv Sources/SentryObjC/Public/SentryObjCBreadcrumb.h Sources/SentryObjC/Public/SentryBreadcrumb.h
git mv Sources/SentryObjC/Public/SentryObjCAttachment.h Sources/SentryObjC/Public/SentryAttachment.h
git mv Sources/SentryObjC/Public/SentryObjCLevel.h Sources/SentryObjC/Public/SentryLevel.h
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "ref: rename SentryObjC user and context headers"
```

---

### Task 3: Rename Exception and Stack Headers

**Files:**

- Rename: `Sources/SentryObjC/Public/SentryObjCException.h` → `SentryException.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCFrame.h` → `SentryFrame.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCStacktrace.h` → `SentryStacktrace.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCThread.h` → `SentryThread.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCMechanism.h` → `SentryMechanism.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCMechanismContext.h` → `SentryMechanismContext.h`

- [ ] **Step 1: Rename exception-related headers**

```bash
git mv Sources/SentryObjC/Public/SentryObjCException.h Sources/SentryObjC/Public/SentryException.h
git mv Sources/SentryObjC/Public/SentryObjCFrame.h Sources/SentryObjC/Public/SentryFrame.h
git mv Sources/SentryObjC/Public/SentryObjCStacktrace.h Sources/SentryObjC/Public/SentryStacktrace.h
git mv Sources/SentryObjC/Public/SentryObjCThread.h Sources/SentryObjC/Public/SentryThread.h
git mv Sources/SentryObjC/Public/SentryObjCMechanism.h Sources/SentryObjC/Public/SentryMechanism.h
git mv Sources/SentryObjC/Public/SentryObjCMechanismContext.h Sources/SentryObjC/Public/SentryMechanismContext.h
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "ref: rename SentryObjC exception and stack headers"
```

---

### Task 4: Rename Tracing Headers

**Files:**

- Rename: `Sources/SentryObjC/Public/SentryObjCSpanId.h` → `SentrySpanId.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCSpanContext.h` → `SentrySpanContext.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCSpanProtocol.h` → `SentrySpan.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCSpanStatus.h` → `SentrySpanStatus.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCTraceContext.h` → `SentryTraceContext.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCTraceHeader.h` → `SentryTraceHeader.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCTransactionContext.h` → `SentryTransactionContext.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCTransactionNameSource.h` → `SentryTransactionNameSource.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCSamplingContext.h` → `SentrySamplingContext.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCSampleDecision.h` → `SentrySampleDecision.h`
- Rename: `Sources/SentryObjC/Public/SentryObjCBaggage.h` → `SentryBaggage.h`

- [ ] **Step 1: Rename tracing headers**

```bash
git mv Sources/SentryObjC/Public/SentryObjCSpanId.h Sources/SentryObjC/Public/SentrySpanId.h
git mv Sources/SentryObjC/Public/SentryObjCSpanContext.h Sources/SentryObjC/Public/SentrySpanContext.h
git mv Sources/SentryObjC/Public/SentryObjCSpanProtocol.h Sources/SentryObjC/Public/SentrySpan.h
git mv Sources/SentryObjC/Public/SentryObjCSpanStatus.h Sources/SentryObjC/Public/SentrySpanStatus.h
git mv Sources/SentryObjC/Public/SentryObjCTraceContext.h Sources/SentryObjC/Public/SentryTraceContext.h
git mv Sources/SentryObjC/Public/SentryObjCTraceHeader.h Sources/SentryObjC/Public/SentryTraceHeader.h
git mv Sources/SentryObjC/Public/SentryObjCTransactionContext.h Sources/SentryObjC/Public/SentryTransactionContext.h
git mv Sources/SentryObjC/Public/SentryObjCTransactionNameSource.h Sources/SentryObjC/Public/SentryTransactionNameSource.h
git mv Sources/SentryObjC/Public/SentryObjCSamplingContext.h Sources/SentryObjC/Public/SentrySamplingContext.h
git mv Sources/SentryObjC/Public/SentryObjCSampleDecision.h Sources/SentryObjC/Public/SentrySampleDecision.h
git mv Sources/SentryObjC/Public/SentryObjCBaggage.h Sources/SentryObjC/Public/SentryBaggage.h
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "ref: rename SentryObjC tracing headers"
```

---

### Task 5: Rename Remaining Headers

**Files:**

- Rename all remaining `SentryObjC*.h` files

- [ ] **Step 1: Rename remaining headers**

```bash
git mv Sources/SentryObjC/Public/SentryObjCMessage.h Sources/SentryObjC/Public/SentryMessage.h
git mv Sources/SentryObjC/Public/SentryObjCRequest.h Sources/SentryObjC/Public/SentryRequest.h
git mv Sources/SentryObjC/Public/SentryObjCDebugMeta.h Sources/SentryObjC/Public/SentryDebugMeta.h
git mv Sources/SentryObjC/Public/SentryObjCNSError.h Sources/SentryObjC/Public/SentryNSError.h
git mv Sources/SentryObjC/Public/SentryObjCAppStartMeasurement.h Sources/SentryObjC/Public/SentryAppStartMeasurement.h
git mv Sources/SentryObjC/Public/SentryObjCReplayApi.h Sources/SentryObjC/Public/SentryReplayApi.h
git mv Sources/SentryObjC/Public/SentryObjCReplayOptions.h Sources/SentryObjC/Public/SentryReplayOptions.h
git mv Sources/SentryObjC/Public/SentryObjCHttpStatusCodeRange.h Sources/SentryObjC/Public/SentryHttpStatusCodeRange.h
git mv Sources/SentryObjC/Public/SentryObjCMeasurementUnit.h Sources/SentryObjC/Public/SentryMeasurementUnit.h
git mv Sources/SentryObjC/Public/SentryObjCLogger.h Sources/SentryObjC/Public/SentryLogger.h
git mv Sources/SentryObjC/Public/SentryObjCError.h Sources/SentryObjC/Public/SentryError.h
git mv Sources/SentryObjC/Public/SentryObjCSerializable.h Sources/SentryObjC/Public/SentrySerializable.h
git mv Sources/SentryObjC/Public/SentryObjCDefines.h Sources/SentryObjC/Public/SentryDefines.h
git mv Sources/SentryObjC/Public/SentryObjCAttributeContent.h Sources/SentryObjC/Public/SentryAttributeContent.h
git mv Sources/SentryObjC/Public/SentryObjCMetric.h Sources/SentryObjC/Public/SentryMetric.h
git mv Sources/SentryObjC/Public/SentryObjCMetricValue.h Sources/SentryObjC/Public/SentryMetricValue.h
git mv Sources/SentryObjC/Public/SentryObjCMetricsApi.h Sources/SentryObjC/Public/SentryMetricsApi.h
git mv Sources/SentryObjC/Public/SentryObjCRedactRegionType.h Sources/SentryObjC/Public/SentryRedactRegionType.h
git mv Sources/SentryObjC/Public/SentryObjCUnit.h Sources/SentryObjC/Public/SentryUnit.h
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "ref: rename remaining SentryObjC headers"
```

---

## Phase 2: Update Internal References

### Task 6: Update Umbrella Header

**Files:**

- Modify: `Sources/SentryObjC/Public/SentryObjC.h`

- [ ] **Step 1: Update all imports in umbrella header**

Replace all `#import "SentryObjC*.h"` with `#import "Sentry*.h"` (without the ObjC prefix).

The umbrella header should import:

```objc
#import <Foundation/Foundation.h>

#import "SentryDefines.h"

// Core types
#import "SentrySDK.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#import "SentryEvent.h"
#import "SentryId.h"
#import "SentryLevel.h"

// User and context
#import "SentryUser.h"
#import "SentryGeo.h"
#import "SentryBreadcrumb.h"
#import "SentryAttachment.h"

// Exception and stack
#import "SentryException.h"
#import "SentryFrame.h"
#import "SentryStacktrace.h"
#import "SentryThread.h"
#import "SentryMechanism.h"
#import "SentryMechanismContext.h"
#import "SentryMessage.h"
#import "SentryRequest.h"
#import "SentryDebugMeta.h"
#import "SentryNSError.h"
#import "SentryError.h"

// Tracing
#import "SentrySpanId.h"
#import "SentrySpanContext.h"
#import "SentrySpan.h"
#import "SentrySpanStatus.h"
#import "SentryTraceContext.h"
#import "SentryTraceHeader.h"
#import "SentryTransactionContext.h"
#import "SentryTransactionNameSource.h"
#import "SentrySamplingContext.h"
#import "SentrySampleDecision.h"
#import "SentryBaggage.h"

// Performance
#import "SentryAppStartMeasurement.h"

// Replay
#import "SentryReplayApi.h"
#import "SentryReplayOptions.h"

// Network
#import "SentryHttpStatusCodeRange.h"

// Metrics
#import "SentryMeasurementUnit.h"
#import "SentryAttributeContent.h"
#import "SentryMetric.h"
#import "SentryMetricValue.h"
#import "SentryMetricsApi.h"
#import "SentryUnit.h"
#import "SentryRedactRegionType.h"

// Utilities
#import "SentryLogger.h"
#import "SentrySerializable.h"
```

- [ ] **Step 2: Commit**

```bash
git add Sources/SentryObjC/Public/SentryObjC.h
git commit -m "ref: update umbrella header imports to new names"
```

---

### Task 7: Update Cross-Header Imports

**Files:**

- Modify: All renamed headers that import other SentryObjC headers

- [ ] **Step 1: Find and update cross-references**

Search for `#import "SentryObjC` in all headers and update to new names:

```bash
# Find files with old imports
grep -r '#import "SentryObjC' Sources/SentryObjC/Public/
```

Update each file to use new import names (e.g., `#import "SentryObjCUser.h"` → `#import "SentryUser.h"`).

- [ ] **Step 2: Verify no old imports remain**

```bash
grep -r 'SentryObjC' Sources/SentryObjC/Public/*.h | grep -v 'SentryObjC.h' | grep -v 'SentryObjCSDK'
```

Should return no matches except for class names that legitimately contain "ObjC" (like `SentryObjCSDK`).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "ref: update cross-header imports to new names"
```

---

### Task 8: Rename Class Names in Headers

**Files:**

- Modify: `Sources/SentryObjC/Public/SentrySDK.h` - rename `SentryObjCSDK` → `SentrySDK`

- [ ] **Step 1: Update SentrySDK.h class name**

Change `@interface SentryObjCSDK` to `@interface SentrySDK`.

- [ ] **Step 2: Update implementation file**

Rename `Sources/SentryObjC/SentryObjCSDK.m` to `Sources/SentryObjC/SentrySDK.m` and update class name inside.

```bash
git mv Sources/SentryObjC/SentryObjCSDK.m Sources/SentryObjC/SentrySDK.m
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "ref: rename SentryObjCSDK class to SentrySDK"
```

---

### Task 9: Update Package.swift

**Files:**

- Modify: `Package.swift`

- [ ] **Step 1: Update SentryObjC target if needed**

Verify the `SentryObjC` target in Package.swift still works with renamed files. The target uses `path: "Sources/SentryObjC"` which should still work.

- [ ] **Step 2: Test SPM build**

```bash
swift build --target SentryObjC
```

- [ ] **Step 3: Commit if changes needed**

```bash
git add Package.swift
git commit -m "ref: update Package.swift for renamed headers"
```

---

## Phase 3: Build Infrastructure

### Task 10: Update Ruby Script for Xcode Target

**Files:**

- Modify: `scripts/add-sentryobjc-target.rb`

- [ ] **Step 1: Add SentryObjCBridge sources**

Update the script to include Swift bridge files:

```ruby
# Source files for SentryObjC target
OBJC_SOURCES = Dir.glob('Sources/SentryObjC/**/*.m')
OBJC_HEADERS = Dir.glob('Sources/SentryObjC/**/*.h')
SWIFT_SOURCES = Dir.glob('Sources/SentryObjCBridge/**/*.swift')
```

- [ ] **Step 2: Add Sentry target dependency**

Add dependency on Sentry target so the full SDK is compiled in:

```ruby
# Add dependency on Sentry framework
target.add_dependency(sentry_target)

# Link Sentry.framework
sentry_product = sentry_target.product_reference
if sentry_product
  target.frameworks_build_phase.add_file_reference(sentry_product)
end
```

- [ ] **Step 3: Commit**

```bash
git add scripts/add-sentryobjc-target.rb
git commit -m "build: update add-sentryobjc-target.rb to include bridge and Sentry dependency"
```

---

### Task 11: Add SentryObjC Variant to XCFramework Build

**Files:**

- Modify: `scripts/build-xcframework-local.sh`

- [ ] **Step 1: Add SentryObjC variant**

Add after the existing variants:

```bash
if [ "$variants" = "SentryObjCOnly" ] || [ "$variants" = "AllVariants" ]; then
    ./scripts/build-xcframework-variant.sh "SentryObjC" "" "mh_dylib" "" "$sdks" ""
    ./scripts/validate-xcframework-format.sh "SentryObjC.xcframework"
    ./scripts/compress-xcframework.sh "$signed" SentryObjC
    mv SentryObjC.xcframework.zip XCFrameworkBuildPath/SentryObjC.xcframework.zip
fi
```

- [ ] **Step 2: Commit**

```bash
git add scripts/build-xcframework-local.sh
git commit -m "build: add SentryObjC variant to xcframework build script"
```

---

### Task 12: Test iOS Simulator Build

**Files:**

- Test: Makefile target `build-sentryobjc`

- [ ] **Step 1: Regenerate Xcode target**

```bash
bundle exec ruby scripts/add-sentryobjc-target.rb
```

- [ ] **Step 2: Build for iOS simulator**

```bash
make build-sentryobjc
```

Expected: Build succeeds without errors.

- [ ] **Step 3: Verify framework output**

Check that `SentryObjC.framework` is created with correct structure:

- Headers directory contains renamed headers
- No Swift headers exposed
- Binary contains all symbols

---

### Task 13: Test Full XCFramework Build

**Files:**

- Test: Makefile target `build-sentryobjc-xcframework`

- [ ] **Step 1: Build xcframework (iOS only first)**

```bash
./scripts/build-xcframework-variant.sh SentryObjC '' mh_dylib '' iOSOnly ''
```

Expected: Creates `SentryObjC.xcframework` with ios-arm64 and ios-arm64_x86_64-simulator slices.

- [ ] **Step 2: Validate xcframework structure**

```bash
ls -la SentryObjC.xcframework/
ls -la SentryObjC.xcframework/ios-arm64_x86_64-simulator/SentryObjC.framework/Headers/
```

Expected: Headers directory contains `SentryObjC.h`, `SentrySDK.h`, `SentryOptions.h`, etc. (without "ObjC" prefix except umbrella).

- [ ] **Step 3: Build full xcframework (all platforms)**

```bash
make build-sentryobjc-xcframework
```

Expected: Creates xcframework with all platform slices.

---

## Phase 4: Integration Testing

### Task 14: Update Sample App

**Files:**

- Modify: `Samples/iOS-ObjectiveCpp-NoModules/App/Sources/AppDelegate.mm`

- [ ] **Step 1: Update import if needed**

The import `#import <SentryObjC/SentryObjC.h>` should still work (umbrella header name unchanged).

- [ ] **Step 2: Update class name usage**

Change `[SentryObjCSDK startWithConfigureOptions:...]` to `[SentrySDK startWithConfigureOptions:...]`.

- [ ] **Step 3: Build sample app**

```bash
make build-sample-iOS-ObjectiveCpp-NoModules
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Samples/iOS-ObjectiveCpp-NoModules/
git commit -m "test: update sample app for renamed SentryObjC classes"
```

---

### Task 15: Final Verification

- [ ] **Step 1: Run format check**

```bash
make format
```

- [ ] **Step 2: Run lint check**

```bash
make lint
```

- [ ] **Step 3: Run iOS tests**

```bash
make test-ios
```

- [ ] **Step 4: Create final commit if any fixes needed**

```bash
git add -A
git commit -m "chore: fix linting and formatting issues"
```

---

## Summary

This plan renames all `SentryObjC*.h` headers to `Sentry*.h` (matching main SDK naming), updates internal references, modifies build scripts to include the Swift bridge and Sentry dependency, and tests the full xcframework build pipeline. The result is a standalone `SentryObjC.xcframework` with pure ObjC headers that bundles the complete SDK.
