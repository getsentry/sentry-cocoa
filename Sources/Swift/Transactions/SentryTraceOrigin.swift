// This file is the Swift addition for `SentryTraceOrigins.h` in the `Sentry` module.

/// - Note: Consider adding new origins here, as they are available in Swift without importing the `Sentry` module.
@objcMembers
class SentryTraceOrigin: NSObject {
    static let autoNSData = "auto.file.ns_data"
    static let manualData = "manual.file.data"
}
