// This file is the Swift addition for `SentrySpanOperations.h` in the `Sentry` module.

/// - Note: Consider adding new operations here, as they are available in Swift without importing the `Sentry` module.
@objcMembers
class SentrySpanOperation: NSObject {
    static let fileRead = "file.read"
    static let fileWrite = "file.write"
}
