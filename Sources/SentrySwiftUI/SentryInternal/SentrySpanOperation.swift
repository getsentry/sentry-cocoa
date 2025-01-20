// This file is a subset of the fields defined in `Sources/Swift/Transactions/SentrySpanOperation.swift`.
//
// As the main file is internal in `Sentry`, it can not be exposed to the `SentrySwiftUI` module.
// This file is a workaround to expose the `SentrySpanOperation` class to the `SentrySwiftUI` module.
//
// Discarded approach:
//   - Swift files are public, the auto-generated `Sentry-Swift.h` includes the `SentrySpanOperation` class.
//   - `Sentry-Swift.h` is manually imported to `SentrySwift.h`
//   -
//
// ATTENTION: This file should be kept in sync with the main file.
//            Please add new fields or methods in the main file if possible.

class SentrySpanOperation {
    static let uiLoad = "ui.load"
}
