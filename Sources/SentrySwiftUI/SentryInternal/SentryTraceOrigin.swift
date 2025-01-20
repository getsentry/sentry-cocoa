// This file is a subset of the fields defined in `Sources/Swift/Transactions/SentryTraceOrigin.swift`.
//
// As the main file is internal in `Sentry`, it can not be exposed to the `SentrySwiftUI` module.
// This file is a workaround to expose the `SentrySpanOperation` class to the `SentrySwiftUI` module.
//
// ATTENTION: This file should be kept in sync with the main file.
//            Please add new fields or methods in the main file if possible.
//
// Discarded Approach 1:
//   - Define `@interface SentryTraceOrigin` in `SentryInternal.h`
//   - Swift class is exposed to Objective-C in auto-generated `Sentry-Swift.h`
//   - Conflict: Duplicate interface definition
//
// Discarded Approach 2:
//   - Declare Swift class `SentryTraceOrigin` in main file as `public`.
//   - Auto-generated `Sentry-Swift.h` is manually imported to `SentrySwift.h`
//   - Issue: Internal class is public for SDK users, which is not desired

enum SentryTraceOrigin: String {
    case autoUITimeToDisplay = "auto.ui.time_to_display"
}
