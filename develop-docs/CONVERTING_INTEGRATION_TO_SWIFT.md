# Converting Objective-C Integrations to Swift

This guide documents the process for converting an Objective-C integration to Swift, following the pattern established by `SentryScreenshotIntegration` and `SentryViewHierarchyIntegration`.

## Overview

The conversion process involves:

1. Creating a Swift integration class following the `SwiftIntegration` protocol
2. Setting up dependency injection via protocols
3. Registering the integration in the Swift integration installer
4. Removing old Objective-C files and references
5. Converting test helpers and updating tests
6. Updating project files

## Step-by-Step Process

### 1. Analyze the Existing Objective-C Integration

Before starting, understand:

- What the integration does
- What dependencies it requires
- How it's initialized and uninstalled
- What protocols it conforms to (e.g., `SentryClientAttachmentProcessor`)
- How it's registered in `SentrySDKInternal.m`

**Example:** `SentryViewHierarchyIntegration` was an `SentryBaseIntegration` that implemented `SentryClientAttachmentProcessor` and required `SentryViewHierarchyProvider` from the dependency container.

### 2. Create the Swift Integration File

Create a new Swift file at `Sources/Swift/Integrations/[IntegrationName]/[IntegrationName]Integration.swift`.

**Template:**

```swift
@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT

final class [IntegrationName]Integration<Dependencies: [IntegrationName]IntegrationProvider>: NSObject, SwiftIntegration, [Protocols] {
    private let options: Options
    private let [dependency]: [DependencyType]
    private weak var client: SentryClientInternal?

    init?(with options: Options, dependencies: Dependencies) {
        guard options.[enableOption] else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because [option] is disabled.")
            return nil
        }

        guard let [dependency] = dependencies.[dependency] else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because [dependency] is not available.")
            return nil
        }

        self.options = options
        self.[dependency] = [dependency]

        super.init()

        if let client = SentrySDKInternal.currentHub().getClient() {
            self.client = client
            client.[registerMethod](self)
        }

        // Additional setup...
    }

    func uninstall() {
        // Cleanup...
        client?.[unregisterMethod](self)
    }

    static var name: String {
        "[IntegrationName]Integration"
    }

    // MARK: - Protocol Implementations
    
    // Implement required protocol methods...
}

#endif // (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT
```

**Key Points:**

- Use `@_implementationOnly import _SentryPrivate` for internal Objective-C types
- Make the class `final` and generic over a dependency provider protocol
- Use failable initializer (`init?`) that returns `nil` if integration shouldn't be enabled
- Store dependencies as properties
- Register with client in `init`, unregister in `uninstall()`
- Implement `static var name: String` for integration identification

### 3. Create Dependency Injection Protocol

**Option A: Use a Typealias (Preferred when combining existing providers)**

If your integration only needs dependencies that are already provided by existing provider protocols, use a typealias to combine them. Define the typealias in your integration file:

```swift
// In [IntegrationName]Integration.swift
typealias [IntegrationName]IntegrationProvider = ExistingProvider1 & ExistingProvider2 & ExistingProvider3
```

**Example:**

```swift
// In SentryAutoBreadcrumbTrackingIntegration.swift
typealias AutoBreadcrumbTrackingIntegrationProvider = FileManagerProvider & NotificationCenterProvider

final class SentryAutoBreadcrumbTrackingIntegration<Dependencies: AutoBreadcrumbTrackingIntegrationProvider>: NSObject, SwiftIntegration {
    // ...
}
```

**Benefits:**

- Reuses existing provider protocols
- No need to create a new protocol
- Keeps dependency requirements close to the integration
- Follows the pattern used by `SentryHangTrackingIntegration`

**Option B: Create a New Protocol (When you need a custom dependency)**

If your integration requires a dependency that doesn't have an existing provider protocol, create a new protocol in `Sources/Swift/SentryDependencyContainer.swift`:

```swift
protocol [IntegrationName]IntegrationProvider {
    var [dependency]: [DependencyType]? { get }
}

extension SentryDependencyContainer: [IntegrationName]IntegrationProvider { }
```

**Important:** The dependency property in `SentryDependencyContainer` must be optional (`?`) to conform to the protocol.

**Example:**

```swift
// In SentryDependencyContainer
private var _viewHierarchyProvider: SentryViewHierarchyProvider?
@objc public lazy var viewHierarchyProvider: SentryViewHierarchyProvider? = getOptionalLazyVar(\._viewHierarchyProvider) {
    SentryViewHierarchyProvider(dispatchQueueWrapper: dispatchQueueWrapper, applicationProvider: defaultApplicationProvider)
}

// Protocol
protocol ViewHierarchyIntegrationProvider {
    var viewHierarchyProvider: SentryViewHierarchyProvider? { get }
}

extension SentryDependencyContainer: ViewHierarchyIntegrationProvider { }
```

**Available Provider Protocols:**

Common provider protocols available in `SentryDependencyContainer.swift`:

- `FileManagerProvider` - provides `fileManager: SentryFileManager?`
- `NotificationCenterProvider` - provides `notificationCenterWrapper: SentryNSNotificationCenterWrapper`
- `DispatchQueueWrapperProvider` - provides `dispatchQueueWrapper: SentryDispatchQueueWrapper`
- `CrashWrapperProvider` - provides `crashWrapper: SentryCrashWrapper`
- `ThreadInspectorProvider` - provides `threadInspector: SentryThreadInspector`
- `DebugImageProvider` - provides `debugImageProvider: SentryDebugImageProvider`
- `ExtensionDetectorProvider` - provides `extensionDetector: SentryExtensionDetector`
- `ANRTrackerBuilder` - provides `getANRTracker(_:) -> SentryANRTracker`

**Reference:** See `SentryHangTrackingIntegration.swift` for an example of combining multiple providers with a typealias.

### 4. Register the Integration

Add the integration to `Sources/Swift/Core/Integrations/Integrations.swift`:

```swift
#if (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT
integrations.append(.init([IntegrationName]Integration.self))
#endif
```

### 5. Expose Objective-C Headers to Swift

If your Swift integration uses Objective-C classes or protocols, you need to expose them via `SentryPrivate.h`:

**Add to `Sources/Sentry/include/SentryPrivate.h`:**

```objc
#import "[ObjectiveCClass].h"
#import "[ObjectiveCProtocol].h"
```

**Important:** Add these imports unconditionally (without `#if` conditionals) even if the Objective-C classes are conditionally compiled. This ensures Swift can see the types at compile time. The Objective-C implementation will handle the conditional compilation logic.

**Example:** When converting `SentryAutoBreadcrumbTrackingIntegration`, we added:

```objc
#import "SentryBreadcrumbDelegate.h"
#import "SentryBreadcrumbTracker.h"
#import "SentrySystemEventBreadcrumbs.h"
```

These headers are now accessible via `@_implementationOnly import _SentryPrivate` in Swift files.

### 6. Handle Conditionally Compiled Objective-C Classes

If your integration needs to initialize Objective-C classes that are conditionally compiled (e.g., only available on iOS), Swift may not see the initializer at compile time. Use runtime initialization with `NSClassFromString` and `performSelector`:

**Pattern:**

```swift
#if os(iOS) && !SENTRY_NO_UIKIT
// Note: [ClassName] is conditionally compiled, so we use performSelector
guard let classType = NSClassFromString("[ClassName]") as? NSObject.Type,
      let allocated = classType.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
      let instance = allocated.perform(NSSelectorFromString("initWith[Param1]:and[Param2]:"), with: param1, with: param2)?.takeUnretainedValue() as? [ClassName] else {
    SentrySDKLog.warning("Failed to create [ClassName] - class may not be available on this platform")
    return nil
}
self.property = instance
instance.start(with: self)
#endif
```

**Example:** `SentryAutoBreadcrumbTrackingIntegration` uses this pattern for `SentrySystemEventBreadcrumbs`:

```swift
#if os(iOS) && !SENTRY_NO_UIKIT
guard let systemEventBreadcrumbsClass = NSClassFromString("SentrySystemEventBreadcrumbs") as? NSObject.Type,
      let allocated = systemEventBreadcrumbsClass.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
      let systemEventBreadcrumbs = allocated.perform(NSSelectorFromString("initWithFileManager:andNotificationCenterWrapper:"), with: fileManager, with: notificationCenterWrapper)?.takeUnretainedValue() as? SentrySystemEventBreadcrumbs else {
    SentrySDKLog.warning("Failed to create SentrySystemEventBreadcrumbs - class may not be available on this platform")
    return nil
}
self.systemEventBreadcrumbs = systemEventBreadcrumbs
systemEventBreadcrumbs.start(with: self)
#endif
```

**Note:** This pattern is only needed when Swift cannot see the Objective-C initializer at compile time due to conditional compilation. If the class is always available, use normal Swift initialization.

### 7. Remove Old Objective-C Integration

1. **Remove from `SentrySDKInternal.m`:**
   - Remove `#import "[IntegrationName]Integration.h"`
   - Remove `[[IntegrationName]Integration class]` from `defaultIntegrationClasses` array

2. **Delete the Objective-C files:**
   - `Sources/Sentry/[IntegrationName]Integration.m`
   - `Sources/Sentry/include/[IntegrationName]Integration.h`

3. **Remove from bridging header:**
   - Remove `#import "[IntegrationName]Integration.h"` from `Tests/SentryTests/SentryTests-Bridging-Header.h` (if present)
   - Remove any test-specific headers like `#import "[IntegrationName]Integration+Test.h"`

### 8. Handle C Interoperability (if needed)

If the integration uses C function callbacks (e.g., `sentrycrash_setSaveViewHierarchy`), handle them in the Swift integration:

```swift
sentrycrash_setSaveViewHierarchy { path in
    guard let path = path else { return }
    let reportPath = String(cString: path)
    let filePath = (reportPath as NSString).appendingPathComponent("view-hierarchy.json")
    SentryDependencyContainer.sharedInstance().viewHierarchyProvider?.saveViewHierarchy(filePath)
}
```

**Note:** Access `SentryDependencyContainer.sharedInstance()` directly within the closure, not through captured variables, to match the original Objective-C pattern.

### 9. Convert Test Helpers (if needed)

If there are Objective-C test helpers that expose C functions, convert them to Swift using `@_cdecl`:

**Create:** `Tests/SentryTests/Integrations/[IntegrationName]/[IntegrationName]IntegrationTestHelper.swift`

```swift
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

@_spi(Private) import Sentry

/**
 * Function to call through to [functionality], which can be passed around
 * as a function pointer in the C crash reporting code or called directly from tests.
 */
@_cdecl("[functionName]")
public func [functionName](_[parameter]: UnsafePointer<CChar>?) {
    guard let [parameter] = [parameter] else { return }
    // Implementation...
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
```

**Remove:** The old Objective-C test helper file (`.m` and `.h` if separate).

### 10. Update Tests

Update test files to use the new Swift integration:

**Before (Objective-C pattern):**

```swift
func getSut() -> SentryViewHierarchyIntegration {
    let result = SentryViewHierarchyIntegration()
    return result
}

func test_processAttachments() {
    let sut = fixture.getSut()
    // ...
}
```

**After (Swift pattern):**

```swift
@testable import Sentry
@_spi(Private) import _SentryPrivate
import XCTest

class [IntegrationName]IntegrationTests: XCTestCase {
    private class Fixture {
        let fileManager: TestFileManager
        let defaultOptions: Options
        
        init() throws {
            let options = Options()
            options.dsn = TestConstants.dsnForTestCase(type: [IntegrationName]IntegrationTests.self)
            options.enable[Feature] = true  // Enable required option
            defaultOptions = options
            
            fileManager = try TestFileManager(
                options: options,
                andCurrentDateProvider: TestCurrentDateProvider()
            )
        }
        
        func getSut(options: Options? = nil) throws -> [IntegrationName]Integration<SentryDependencyContainer> {
            let container = SentryDependencyContainer.sharedInstance()
            container.fileManager = fileManager
            // Set other required dependencies...
            
            return try XCTUnwrap([IntegrationName]Integration(
                with: options ?? defaultOptions,
                dependencies: container
            ))
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = try! Fixture()
    }
    
    func test_[feature]() throws {
        let sut = try fixture.getSut()
        defer {
            sut.uninstall()
        }
        // Test implementation...
    }
}
```

**Key Changes:**

- Add `@_spi(Private) import _SentryPrivate` to access internal Objective-C types
- Use failable initializer with `try XCTUnwrap`
- Add `defer { sut.uninstall() }` for cleanup
- Make test methods `throws` if they use `getSut()`
- Update `Fixture` to include `defaultOptions` with required options enabled
- Set dependencies on `SentryDependencyContainer.sharedInstance()` in `getSut()`
- For disabled integration tests, assert `XCTAssertNil(sut)` when the integration returns `nil`

### 11. Update Project Files

The Xcode project file (`Sentry.xcodeproj/project.pbxproj`) needs to be updated:

1. **Remove old Objective-C file references:**
   - Remove `PBXBuildFile` entries for `.m` and `.h` files
   - Remove `PBXFileReference` entries
   - Remove from build phases (Sources and Headers)
   - Remove from groups

2. **Add new Swift file references:**
   - Add `PBXBuildFile` entry for `.swift` file
   - Add `PBXFileReference` entry
   - Add to Sources build phase
   - Add to appropriate group (e.g., `Sources/Swift/Integrations/[IntegrationName]`)

**Note:** Xcode usually handles these changes automatically when you add/remove files through the IDE, but manual editing may be needed if files are added/removed via command line.

### 12. Clean Up Unused Headers

Remove any test-only header files that are no longer needed:

- Check `Tests/SentryTests/Integrations/[IntegrationName]/` for unused `.h` files
- Remove imports from `SentryTests-Bridging-Header.h` if they're no longer needed

**Example:** `TestSentryViewHierarchyProvider.h` was removed because it only declared unused category methods.

### 13. Verify the Conversion

1. **Build the project:**
   ```bash
   xcodebuild -workspace Sentry.xcworkspace -scheme Sentry -destination 'platform=iOS Simulator,id=[SIMULATOR_ID]' build
   ```

2. **Run tests:**
   ```bash
   xcodebuild -workspace Sentry.xcworkspace -scheme Sentry -destination 'platform=iOS Simulator,id=[SIMULATOR_ID]' test -only-testing:SentryTests/[IntegrationName]IntegrationTests
   ```

3. **Check for:**
   - No compilation errors
   - All tests pass
   - Integration is properly registered and functional
   - No memory leaks or retain cycles

## Common Patterns

### Type Naming Differences

When working with Objective-C types in Swift, be aware of naming differences:

- `SentryBreadcrumb` → `Breadcrumb` (Swift removes the `Sentry` prefix for some types)
- `SentryOptions` → `Options`
- `SentryEvent` → `Event`

Check the Swift interface or use Xcode's "Jump to Definition" to verify the correct Swift name.

### Attachment Processor Integration

For integrations that implement `SentryClientAttachmentProcessor`:

```swift
func processAttachments(_ attachments: [Attachment], for event: Event) -> [Attachment] {
    // Early returns for conditions where attachment shouldn't be added
    if (event.exceptions == nil && event.error == nil) || event.isFatalEvent {
        return attachments
    }

    // Additional checks...
    
    // Create and return attachment
    let attachment = Attachment(
        data: data,
        filename: "filename.ext",
        contentType: "content/type",
        attachmentType: .[type]
    )

    return attachments + [attachment]
}
```

### C Callback Handling

When setting C callbacks, use closures that access the dependency container directly:

```swift
sentrycrash_set[Callback] { [parameters] in
    guard let [parameters] = [parameters] else { return }
    // Access SentryDependencyContainer.sharedInstance() directly
    SentryDependencyContainer.sharedInstance().[dependency]?.[method]([args])
}
```

**Avoid:** Using global variables or capturing dependencies in closures unnecessarily.

## Troubleshooting

### Integration Not Found in Tests

If tests can't find the Swift integration class:

- Ensure the file is added to the Sentry target (not just test target)
- Verify the class is `internal` (default) - it should be accessible via `@testable import Sentry`
- Check that platform conditionals match between integration and tests
- Try a clean build (`Product > Clean Build Folder` in Xcode)

### C Function Not Found

If C functions aren't accessible:

- Ensure test helper uses `@_cdecl` attribute
- Check that the function is `public` (required for `@_cdecl`)
- Verify the bridging header includes necessary C headers (if needed)

### Dependency Injection Issues

If dependency injection fails:

- Ensure the dependency property in `SentryDependencyContainer` is optional
- Verify the protocol matches the property signature exactly
- Check that `getOptionalLazyVar` is used for optional dependencies
- In tests, ensure dependencies are set on `SentryDependencyContainer.sharedInstance()` before creating the integration

### Objective-C Types Not Found in Swift

If Swift cannot find Objective-C types:

- Ensure the Objective-C headers are added to `Sources/Sentry/include/SentryPrivate.h`
- Add them unconditionally (without `#if` conditionals) even if the Objective-C implementation is conditionally compiled
- Verify `@_implementationOnly import _SentryPrivate` is used in the Swift file
- For conditionally compiled classes, use runtime initialization with `NSClassFromString` and `performSelector` (see Step 6)

### Conditionally Compiled Classes

If you get errors like "initializer 'init(...)' with Objective-C selector 'init...' conflicts" or "argument passed to call that takes no arguments":

- The Objective-C class may be conditionally compiled, making it invisible to Swift at compile time
- Use the runtime initialization pattern documented in Step 6
- Ensure the class name string matches exactly (including capitalization)
- Verify the selector string matches the Objective-C method signature exactly (e.g., `initWithFileManager:andNotificationCenterWrapper:`)

## References

- `SentryScreenshotIntegration.swift` - First Swift integration example
- `SentryViewHierarchyIntegration.swift` - Second Swift integration example
- `SentryAutoBreadcrumbTrackingIntegration.swift` - Example with conditionally compiled Objective-C classes and typealias dependency injection
- `SentryHangTrackingIntegration.swift` - Example using typealias for combining multiple provider protocols
- `Sources/Swift/Core/Integrations/Integrations.swift` - Integration registration
- `Sources/Swift/SentryDependencyContainer.swift` - Dependency injection setup
- `Sources/Sentry/include/SentryPrivate.h` - Objective-C headers exposed to Swift
