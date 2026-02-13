# Phase 3: ObjC Isolation - Research

**Researched:** 2026-02-13
**Domain:** Objective-C dependency injection, Swift-ObjC interoperability, crash handler thread safety
**Confidence:** HIGH

## Summary

Phase 3 requires passing a Swift facade (SentryCrashBridge) into Objective-C SentryCrash files to eliminate their direct dependency on SentryDependencyContainer. The research reveals this is architecturally straightforward: SentryCrashBridge is already @objc accessible, and the three target ObjC files (SentryCrash.m, SentryCrashInstallation.m, SentryCrashMonitor_NSException.m) all receive their dependencies through existing initialization or property access patterns that can be adapted.

The key insight is that these ObjC files don't need to "own" the bridge—they can receive it via property injection from SentryCrashIntegration (Swift), which already manages the bridge lifecycle. The bridge must remain a property of SentryCrashIntegration to ensure proper lifetime management, as crash handling requires the bridge to outlive individual crash events.

**Primary recommendation:** Use property injection pattern—add an optional bridge property to each target ObjC class (SentryCrash, SentryCrashInstallation), then have SentryCrashIntegration inject the bridge immediately after instantiation but before install() is called.

## Standard Stack

### Core Components

| Component               | Version      | Purpose                                       | Why Standard                                                        |
| ----------------------- | ------------ | --------------------------------------------- | ------------------------------------------------------------------- |
| SentryCrashBridge.swift | Current      | Swift-to-ObjC facade providing five services  | Already implemented in Phase 1, @objc accessible, NSObject subclass |
| @objc @_spi(Private)    | Swift 5.9+   | Swift-ObjC interoperability annotation        | Standard pattern in sentry-cocoa for internal-but-bridged APIs      |
| NSObject inheritance    | Foundation   | Base class for Swift classes exposed to ObjC  | Required for ObjC runtime integration                               |
| Property injection      | ObjC pattern | Setting dependencies via properties post-init | Standard pattern in sentry-cocoa for circular dependencies          |

### ObjC Interoperability Requirements

| Requirement                      | Implementation                           | Verification                         |
| -------------------------------- | ---------------------------------------- | ------------------------------------ |
| Swift class accessible from ObjC | `@objc` attribute + NSObject inheritance | SentryCrashBridge already meets this |
| Private/internal visibility      | `@_spi(Private)` annotation              | Already applied to SentryCrashBridge |
| Generated header import          | `#import "Sentry-Swift.h"` in .m files   | Standard sentry-cocoa pattern        |
| Nullability annotations          | Properties must be nullable or nonnull   | Bridge will be optional (nullable)   |

**Installation:**
No new dependencies required. Uses existing Swift-ObjC bridging infrastructure.

## Architecture Patterns

### Recommended Project Structure

```
Sources/
├── Swift/Integrations/SentryCrash/
│   ├── SentryCrashIntegration.swift  # Owns bridge instance
│   └── SentryCrashBridge.swift       # Facade (Phase 1)
└── SentryCrash/
    ├── Recording/
    │   ├── SentryCrash.m             # Receives bridge via property
    │   └── Monitors/
    │       └── SentryCrashMonitor_NSException.m  # Accesses via SentryCrash property
    └── Installations/
        └── SentryCrashInstallation.m # Receives bridge via property
```

### Pattern 1: Property Injection (Recommended)

**What:** Swift integration creates bridge and injects it into ObjC objects via properties

**When to use:** When circular dependencies exist (ObjC needs Swift, Swift needs ObjC), or when object creation precedes configuration

**Example:**

```objc
// SentryCrash.h
@class SentryCrashBridge;

@interface SentryCrash : NSObject
@property (nonatomic, strong, nullable) SentryCrashBridge *bridge;
- (instancetype)initWithBasePath:(NSString *)basePath NS_DESIGNATED_INITIALIZER;
- (BOOL)install;
@end
```

```objc
// SentryCrash.m
#import "Sentry-Swift.h"

- (BOOL)install {
    // Use bridge if available, fall back to container if not (backward compat)
    id<SentryNSNotificationCenterWrapper> notificationCenter =
        self.bridge ? self.bridge.notificationCenterWrapper
                   : SentryDependencyContainer.sharedInstance.notificationCenterWrapper;

    [notificationCenter addObserver:self ...];
    return true;
}
```

```swift
// SentryCrashIntegration.swift
let bridge = SentryCrashBridge(...)
self.bridge = bridge

// Inject bridge before install
let sentryCrash = crashReporter.sentryCrash  // Assuming accessor exists
sentryCrash.bridge = bridge
sentryCrash.install()
```

**Why this pattern:**

- Avoids circular dependency (SentryCrash doesn't need to import bridge at init time)
- Maintains existing initialization patterns (no breaking changes to init signatures)
- Allows gradual migration (ObjC can check `if (self.bridge)` and fall back to container)
- Bridge lifetime managed by Swift (SentryCrashIntegration owns it)

### Pattern 2: Access via Existing Wrappers

**What:** Use existing Swift wrapper classes to expose bridge to wrapped ObjC instances

**When to use:** When Swift already wraps the ObjC class (like SentryCrashSwift wraps SentryCrash)

**Example:**

```swift
// SentryCrashSwift.swift
@_spi(Private) @objc public final class SentryCrashSwift: NSObject {
    private let sentryCrash: SentryCrash

    @objc public func setBridge(_ bridge: SentryCrashBridge) {
        sentryCrash.bridge = bridge
    }
}
```

### Pattern 3: Thread-Safe Access in Crash Handlers

**What:** Ensure bridge properties are accessed safely in crash/signal handler context

**When to use:** For any code called from signal handlers or crash callbacks

**Critical constraints:**

- Signal handlers cannot use mutexes (will deadlock if mutex held by crashed thread)
- Cannot allocate memory in signal handler context
- Must use async-signal-safe APIs only
- Bridge instance must be pre-allocated and stable (no deallocation risk)

**Example:**

```objc
// SentryCrashMonitor_NSException.m
static void setEnabled(bool isEnabled) {
    if (isEnabled) {
        // Bridge access is safe here - NOT in signal handler context
        // This runs during setup, not during crash
        SentryCrashBridge *bridge = g_sentryCrashInstance.bridge;
        if (bridge && bridge.uncaughtExceptionHandler) {
            g_previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
            NSSetUncaughtExceptionHandler(&handleUncaughtException);
            bridge.uncaughtExceptionHandler = &handleUncaughtException;
        }
    }
}
```

**Warning:** The bridge itself is Swift (with ObjC interop), which means accessing its properties from within a signal handler is **NOT safe**. Bridge should only be accessed during setup/configuration phases, not during actual crash handling. Any data needed during crash handling must be extracted from the bridge during setup and stored in C global variables.

### Anti-Patterns to Avoid

- **Don't pass bridge through init signatures:** This creates circular dependencies (Swift needs ObjC instance, ObjC init needs Swift bridge)
- **Don't access Swift objects in signal handlers:** Even @objc Swift objects use Swift runtime, which is not async-signal-safe
- **Don't use bridge as singleton:** The bridge is owned by SentryCrashIntegration and should have the same lifetime
- **Don't inject bridge after install():** Bridge must be set before calling install() to ensure notifications register correctly

## Don't Hand-Roll

| Problem                | Don't Build           | Use Instead                               | Why                                                                                   |
| ---------------------- | --------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------- |
| Swift-ObjC bridging    | Custom interop layer  | `@objc` + NSObject                        | Apple's official mechanism, handles memory management, ARC bridging, type conversions |
| Thread-safe crash data | Custom locking        | Pre-computed C globals                    | Signal handlers can't use locks; only async-safe APIs allowed                         |
| Property ownership     | Manual retain/release | `@property (nonatomic, strong, nullable)` | ARC handles reference counting correctly across Swift-ObjC boundary                   |
| Bridge lifetime        | Singleton pattern     | Integration-owned instance                | Follows SDK architecture where integrations own their subsystems                      |

**Key insight:** Crash handling has severe technical constraints (no malloc, no locks, async-signal-safe only). Any data needed during a crash must be prepared beforehand in safe memory. Don't try to access Swift or ObjC objects from signal handlers—extract needed data during setup and store in C globals.

## Common Pitfalls

### Pitfall 1: Accessing Swift Objects in Signal Handlers

**What goes wrong:** Signal handler crashes or deadlocks when trying to access Swift bridge properties

**Why it happens:** Signal handlers interrupt arbitrary code—if Swift runtime holds a lock, accessing Swift objects will deadlock

**How to avoid:**

- Only access bridge during setup (before crashes occur)
- Extract needed data from bridge into C global variables during setup
- Never call Swift code from signal handler context

**Warning signs:**

- Crash handler hangs indefinitely
- EXC_BAD_ACCESS when accessing bridge properties from crash callback
- Deadlocks during crash reporting

**Example of correct approach:**

```objc
// WRONG - accessing Swift object in signal handler
static void handleSignal(int sigNum) {
    // This will likely crash/deadlock!
    SentryCrashBridge *bridge = g_sentryCrash.bridge;
    id wrapper = bridge.notificationCenterWrapper;  // BAD
}

// RIGHT - extract during setup, store in C global
static void *g_notificationCenterWrapper = NULL;

- (BOOL)install {
    // During setup (safe Swift access)
    g_notificationCenterWrapper = (__bridge void *)self.bridge.notificationCenterWrapper;
    sentrycrash_install(...);  // This registers signal handlers
}

static void handleSignal(int sigNum) {
    // In signal handler - use C global (safe)
    // Only use g_notificationCenterWrapper with async-safe operations
}
```

### Pitfall 2: Circular Dependency at Initialization

**What goes wrong:** Swift needs to create ObjC object, ObjC init needs Swift bridge → chicken-and-egg

**Why it happens:** Trying to pass bridge through ObjC initializer signatures

**How to avoid:** Use property injection pattern—create ObjC object first, then inject bridge via property

**Warning signs:**

- Compiler errors about forward declarations
- "Use of undeclared type" errors
- Complex import dependencies between Swift and ObjC

**Example:**

```swift
// WRONG - circular dependency
let bridge = SentryCrashBridge(...)
let crash = SentryCrash(basePath: path, bridge: bridge)  // Requires ObjC init to know about Swift type

// RIGHT - property injection
let bridge = SentryCrashBridge(...)
let crash = SentryCrash(basePath: path)
crash.bridge = bridge  // Inject after creation
crash.install()
```

### Pitfall 3: Bridge Lifetime Management

**What goes wrong:** Bridge is deallocated while ObjC still holds reference, causing crashes

**Why it happens:** Misunderstanding of ARC and strong/weak references across Swift-ObjC boundary

**How to avoid:**

- Bridge must be owned by SentryCrashIntegration (strong reference)
- ObjC properties should be `strong` (retained) to prevent premature deallocation
- Integration must outlive crash handler (stored on Hub)

**Warning signs:**

- Crashes when accessing bridge properties (EXC_BAD_ACCESS)
- Bridge is nil unexpectedly
- Sporadic crashes during crash reporting

**Example:**

```swift
// WRONG - bridge is local variable, will be deallocated
func installCrashHandler() {
    let bridge = SentryCrashBridge(...)  // Local variable
    sentryCrash.bridge = bridge
    sentryCrash.install()
}  // bridge deallocated here!

// RIGHT - bridge is instance property
class SentryCrashIntegration {
    private var bridge: SentryCrashBridge?  // Strong reference

    func install() {
        let bridge = SentryCrashBridge(...)
        self.bridge = bridge  // Retained by integration
        sentryCrash.bridge = bridge
        sentryCrash.install()
    }
}
```

### Pitfall 4: Forgetting Backward Compatibility

**What goes wrong:** Removing container access immediately breaks tests or existing code paths

**Why it happens:** Not all code paths may have bridge set immediately during migration

**How to avoid:** Use fallback pattern: `self.bridge ? self.bridge.service : SentryDependencyContainer.sharedInstance.service`

**Warning signs:**

- Test failures about nil bridge
- Crashes in edge cases (early uninstall, partial initialization)

**Example:**

```objc
// Support both bridge and direct container access during migration
id<SentryNSNotificationCenterWrapper> notificationCenter = nil;
if (self.bridge) {
    notificationCenter = self.bridge.notificationCenterWrapper;
} else {
    // Fallback for legacy code paths or tests
    notificationCenter = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;
}
```

## Code Examples

Verified patterns based on sentry-cocoa architecture:

### Example 1: Property Injection in SentryCrash.m

```objc
// SentryCrash.h
@class SentryCrashBridge;

@interface SentryCrash : NSObject

// Bridge for accessing SDK services without dependency container
@property (nonatomic, strong, nullable) SentryCrashBridge *bridge;

@property (nonatomic, readwrite, retain) NSString *basePath;
- (instancetype)initWithBasePath:(NSString *)basePath NS_DESIGNATED_INITIALIZER;
- (BOOL)install;
- (void)uninstall;

@end
```

```objc
// SentryCrash.m
#import "SentryCrash.h"
#import "Sentry-Swift.h"  // Provides SentryCrashBridge

@implementation SentryCrash

@synthesize bridge = _bridge;

- (BOOL)install {
    // Pattern: Use bridge if available, fall back to container for compatibility
    id<SentryNSNotificationCenterWrapper> notificationCenter =
        self.bridge ? self.bridge.notificationCenterWrapper
                   : SentryDependencyContainer.sharedInstance.notificationCenterWrapper;

    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    // ... remaining notification registrations
    return true;
}

- (void)uninstall {
    id<SentryNSNotificationCenterWrapper> notificationCenter =
        self.bridge ? self.bridge.notificationCenterWrapper
                   : SentryDependencyContainer.sharedInstance.notificationCenterWrapper;

    [notificationCenter removeObserver:self
                                  name:UIApplicationDidBecomeActiveNotification
                                object:nil];
    // ... remaining cleanup
}

@end
```

### Example 2: Injecting Bridge from Swift Integration

```swift
// SentryCrashIntegration.swift (showing relevant modifications)
final class SentryCrashIntegration<Dependencies: CrashIntegrationProvider>: NSObject, SwiftIntegration {

    private var bridge: SentryCrashBridge?
    private var crashReporter: SentryCrashSwift

    init?(with options: Options, dependencies: Dependencies) {
        // ... existing initialization ...

        // Create bridge BEFORE installing crash handler
        let bridge = SentryCrashBridge(
            notificationCenterWrapper: dependencies.notificationCenterWrapper,
            dateProvider: dependencies.dateProvider,
            crashReporter: dependencies.crashReporter
        )
        self.bridge = bridge

        // Inject bridge into crash reporter wrapper
        crashReporter.setBridge(bridge)

        // Now install crash handler (it will use bridge internally)
        startCrashHandler(...)
    }
}
```

```swift
// SentryCrashSwift.swift (add bridge injection method)
@_spi(Private) @objc public final class SentryCrashSwift: NSObject {

    private let sentryCrash: SentryCrash

    // New method to inject bridge into wrapped ObjC instance
    @objc public func setBridge(_ bridge: SentryCrashBridge) {
        sentryCrash.bridge = bridge
    }

    // ... existing methods ...
}
```

### Example 3: SentryCrashInstallation.m Pattern

```objc
// SentryCrashInstallation+Private.h
@class SentryCrashBridge;

@interface SentryCrashInstallation ()

@property (nonatomic, strong, nullable) SentryCrashBridge *bridge;

- (id)initWithRequiredProperties:(NSArray *)requiredProperties;
- (id<SentryCrashReportFilter>)sink;

@end
```

```objc
// SentryCrashInstallation.m
#import "Sentry-Swift.h"

- (void)install:(NSString *)customCacheDirectory {
    // Use bridge if available for crashReporter access
    SentryCrashSwift *handler = self.bridge ? self.bridge.crashReporter
                                            : SentryDependencyContainer.sharedInstance.crashReporter;

    @synchronized(handler) {
        handler.basePath = customCacheDirectory;
        g_crashHandlerData = self.crashHandlerData;
        [handler setupOnCrash];
        [handler install];
    }
}
```

### Example 4: Thread-Safe Monitor Setup (NSException Monitor)

```objc
// SentryCrashMonitor_NSException.m
#import "Sentry-Swift.h"

// Note: This is called during SETUP, not during crash handling
static void setEnabled(bool isEnabled) {
    if (isEnabled != g_isEnabled) {
        g_isEnabled = isEnabled;
        if (isEnabled) {
            g_previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
            NSSetUncaughtExceptionHandler(&handleUncaughtException);

            // Access bridge during setup (SAFE - not in signal handler)
            // Get crash reporter from global dependency container or via passed reference
            SentryCrashSwift *crashReporter = SentryDependencyContainer.sharedInstance.crashReporter;
            crashReporter.uncaughtExceptionHandler = &handleUncaughtException;
        } else {
            NSSetUncaughtExceptionHandler(g_previousUncaughtExceptionHandler);
        }
    }
}

// This runs DURING crash - must be async-signal-safe (no Swift/ObjC calls)
static void handleUncaughtException(NSException *exception) {
    SENTRY_LOG_DEBUG(@"Trapped exception %@", exception);
    if (g_isEnabled) {
        // Only C functions and async-safe operations here
        // All needed data must be in C globals or exception object
        sentrycrashmc_suspendEnvironment(&threads, &numThreads);
        sentrycrashcm_notifyFatalExceptionCaptured(false);
        // ... rest of async-safe crash handling
    }
}
```

## State of the Art

| Old Approach                      | Current Approach                      | When Changed      | Impact                                                   |
| --------------------------------- | ------------------------------------- | ----------------- | -------------------------------------------------------- |
| Direct container access from ObjC | Property injection with fallback      | Phase 3 (2026)    | Clean architectural boundary, testable without singleton |
| Singleton dependency access       | Explicit dependency passing           | Phases 1-3 (2026) | Better testability, clear dependency graph               |
| ObjC directly imports SDK headers | ObjC receives services through facade | Phase 3 (2026)    | Reduced coupling, cleaner architecture                   |

**Deprecated/outdated:**

- N/A (this is new architecture, not replacing deprecated patterns)

**Current best practices:**

- Bridge is @objc @_spi(Private) with NSObject inheritance (established in Phase 1)
- Property injection for circular dependencies (standard ObjC pattern)
- Fallback to container during migration (ensures compatibility)
- Never access Swift/ObjC from signal handlers (established crash reporting constraint)

## Open Questions

1. **How to handle SentryCrashMonitor_NSException.m's current pattern?**
   - What we know: It sets `crashReporter.uncaughtExceptionHandler` directly on line 127-128
   - What's unclear: Should this go through bridge, or continue direct access since it's in monitor setup code?
   - Recommendation: Keep direct access to crashReporter via container for monitor setup—this runs during configuration, not during crashes. The bridge is primarily for services accessed by SentryCrash.m (notifications) and SentryCrashInstallation.m (crashReporter lifecycle). Monitor setup is distinct.

2. **What about SentryCrashWrapper.swift remaining container references?**
   - What we know: Phase 2 left crashedLastLaunch and activeDurationSinceLastCrash accessing container
   - What's unclear: Are these in scope for Phase 3 or separate cleanup?
   - Recommendation: Include these in Phase 3 as "Swift cleanup" since they're SentryCrash-related container accesses. They should access through bridge.crashReporter instead.

3. **Should bridge injection happen before or after SentryCrash creation?**
   - What we know: Pattern is create → inject bridge → install
   - What's unclear: Is there risk of race conditions if install() called without bridge?
   - Recommendation: SentryCrashIntegration already creates everything in init, so bridge injection happens immediately after crashReporter creation, well before install() is called. No race condition risk.

## Sources

### Primary (HIGH confidence)

- sentry-cocoa codebase:
  - `Sources/Swift/Integrations/SentryCrash/SentryCrashBridge.swift` - Facade implementation from Phase 1
  - `Sources/Swift/Integrations/SentryCrash/SentryCrashIntegration.swift` - Integration pattern
  - `Sources/SentryCrash/Recording/SentryCrash.m` - Target for modification (4 container accesses)
  - `Sources/SentryCrash/Installations/SentryCrashInstallation.m` - Target for modification (3 container accesses)
  - `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_NSException.m` - Target for modification (1 container access)
  - `Tests/SentryTests/Integrations/SentryCrash/SentryCrashIntegrationTests.swift` - Test patterns for dependency injection
  - `develop-docs/SENTRYCRASH.md` - Architecture documentation
  - `AGENTS.md` - Project coding conventions

### Secondary (MEDIUM confidence)

- [iOS Handbook: Swift-Objective-C interoperability](https://infinum.com/handbook/ios/miscellaneous/swift-objective-c-interoperability-and-best-practices) - @objc patterns
- [Apple Developer Forums: Implementing Your Own Crash Reporter](https://developer.apple.com/forums/thread/113742) - Thread safety constraints
- [Apple Developer Forums: Async Signal Safe Functions](https://developer.apple.com/forums/thread/116571) - Signal handler limitations
- [Better Programming: Painless Objective-C and Swift Interoperability](https://betterprogramming.pub/painless-objective-c-and-swift-interoperability-d60318ef0d2e) - NSObject bridging patterns
- [Mike Ash: Signal Handling](https://www.mikeash.com/pyblog/friday-qa-2011-04-01-signal-handling.html) - Crash handler constraints
- [SEI CERT C Coding Standard: SIG30-C](https://wiki.sei.cmu.edu/confluence/display/c/SIG30-C.+Call+only+asynchronous-safe+functions+within+signal+handlers) - Async-safe requirements

### Tertiary (LOW confidence)

- N/A - All findings verified with official docs or codebase examples

## Metadata

**Confidence breakdown:**

- Swift-ObjC interop patterns: HIGH - Verified with existing sentry-cocoa patterns (SentryCrashBridge, test mocks)
- Property injection approach: HIGH - Standard ObjC pattern, used throughout sentry-cocoa
- Thread safety constraints: HIGH - Well-documented crash reporting requirements, verified in SENTRYCRASH.md
- Implementation approach: HIGH - Phase 1-2 established bridge, Phase 3 is application of proven patterns

**Research date:** 2026-02-13
**Valid until:** 60 days (stable architecture, unlikely to change)

**Key constraints:**

- Bridge must remain property of SentryCrashIntegration (lifetime management)
- Bridge injection must happen before install() but after object creation
- No Swift/ObjC access from signal handlers (async-safe only)
- Fallback to container required during migration (test compatibility)
