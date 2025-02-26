import Foundation

/**
 * Trace origin indicates what created a trace or a span
 *
 * The origin is of type string and consists of four parts: `<type>.<category>.<integration-name>.<integration-part>`.
 *
 * Only the first is mandatory. The parts build upon each other, meaning it is forbidden to skip one part.
 * For example, you may send parts one and two but aren't allowed to send parts one and three without part two.
 *
 * - Remark: As  Swift `enum` are not available in Objective-C, it uses a `class` with static properties, marked with `@objc` and `@objcMembers` instead.
 *           To reduce casting between `String` to `NSString` when using from Objective-C, it uses `NSString` instead of `String`.
 *           Eventually this should be replaced with a Swift `enum` when Objective-C compatibility is not needed anymore.
 * - Note: See [Sentry SDK development documenation](https://develop.sentry.dev/sdk/telemetry/traces/trace-origin/) for more information.
*/
@objcMembers @objc(SentryTraceOrigin)
class SentryTraceOrigin: NSObject {
    static let autoAppStart: NSString = "auto.app.start"
    static let autoAppStartProfile: NSString = "auto.app.start.profile"
    static let autoDBCoreData: NSString = "auto.db.core_data"
    static let autoHttpNSURLSession: NSString = "auto.http.ns_url_session"
    static let autoNSData: NSString = "auto.file.ns_data"
    static let autoUiEventTracker: NSString = "auto.ui.event_tracker"
    static let autoUITimeToDisplay: NSString = "auto.ui.time_to_display"
    static let autoUIViewController: NSString = "auto.ui.view_controller"
    static let manual: NSString = "manual"
    static let manualFileData: NSString = "manual.file.data"
    static let manualUITimeToDisplay: NSString = "manual.ui.time_to_display"
}
