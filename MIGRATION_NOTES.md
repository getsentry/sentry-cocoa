# SentryCrashIntegration Swift Migration Notes

## Current Status

The `SentryCrashIntegration` has been converted from Objective-C to Swift, but there are remaining dependencies that need attention:

### Dependencies Requiring Migration

1. **SentryWatchdogTerminationLogic** (Partially Done)
   - The `ref/watchdog-logic-tracker-to-swift` branch has already migrated this to Swift
   - Needs to be merged before this integration can fully compile

2. **SentryCrashIntegrationSessionHandler** (Todo)
   - Currently an Objective-C class
   - Initializers are not properly visible to Swift
   - Recommended: Migrate to Swift with `@objc` annotations

3. **SentryCrashScopeObserver** (Todo)
   - Currently an Objective-C class
   - Initializers are not properly visible to Swift
   - Recommended: Migrate to Swift with `@objc` annotations

## Next Steps

### Option 1: Merge Watchdog Logic Branch First (Recommended)

1. Merge `ref/watchdog-logic-tracker-to-swift` into your branch
2. This provides the Swift version of `SentryWatchdogTerminationLogic`
3. Then migrate the remaining two classes following the same pattern

### Option 2: Migrate Remaining Classes

Follow the pattern from `SentryWatchdogTerminationLogic.swift` in the other branch:

- Mark classes with `@_spi(Private) @objc`
- Use Swift-native types where possible
- Maintain Objective-C compatibility with `@objc` annotations

## Files Modified

### Created

- `Sources/Swift/Integrations/SentryCrash/SentryCrashIntegration.swift`

### Deleted

- `Sources/Sentry/SentryCrashIntegration.m`
- `Sources/Sentry/include/SentryCrashIntegration.h`
- `Tests/SentryTests/Integrations/SentryCrash/SentryCrashIntegration+TestInit.h`

### Modified

- `Sources/Sentry/include/SentryPrivate.h` - Added required headers
- `Sources/Swift/Core/Integrations/Integrations.swift` - Registered Swift integration
- `Sources/Sentry/SentrySDKInternal.m` - Removed Objective-C integration reference
- `Tests/SentryTests/Integrations/SentryCrash/SentryCrashIntegrationTests.swift` - Updated tests
- `Sentry.xcodeproj/project.pbxproj` - Updated project file

## Known Issues

The current implementation will not compile until the Objective-C dependencies are either:

1. Migrated to Swift (recommended)
2. Or properly bridged to Swift with explicit `@objc` annotations
