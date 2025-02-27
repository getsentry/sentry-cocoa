import Foundation

/**
 * Span operations are short string identifiers that categorize the type of operation a span is measuring.
 *
 * They follow a hierarchical dot notation format (e.g. `ui.load.initial_display`) to group related operations.
 * These identifiers help organize and analyze performance data across different types of operations.
 *
 *  - Remark: As  Swift `enum` are not available in Objective-C, it uses a `class` with static properties, marked with `@objc` and `@objcMembers` instead.
 *          To reduce casting between `String` to `NSString` when using from Objective-C, it uses `NSString` instead of `String`.
 *          Eventually this should be replaced with a Swift `enum` when Objective-C compatibility is not needed anymore.
 *  - Note: See [Sentry SDK development documentation](https://develop.sentry.dev/sdk/telemetry/traces/span-operations/) for more information.
 */
@objcMembers @objc(SentrySpanOperation)
class SentrySpanOperation: NSObject {
    static let appLifecycle: NSString = "app.lifecycle"

    static let coredataFetchOperation: NSString = "db.sql.query"
    static let coredataSaveOperation: NSString = "db.sql.transaction"

    static let fileRead: NSString = "file.read"
    static let fileWrite: NSString = "file.write"
    static let fileCopy: NSString = "file.copy"
    static let fileRename: NSString = "file.rename"
    static let fileDelete: NSString = "file.delete"

    static let networkRequestOperation: NSString = "http.client"

    static let uiAction: NSString = "ui.action"
    static let uiActionClick: NSString = "ui.action.click"

    static let uiLoad: NSString = "ui.load"
    static let uiLoadInitialDisplay: NSString = "ui.load.initial_display"
    static let uiLoadFullDisplay: NSString = "ui.load.full_display"
}
