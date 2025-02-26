import Foundation

/**
 * Constants for span data field keys.
 *
 * These keys are used to attach additional data to spans in a standardized way.
 *
 * The keys follow [OpenTelemetry's semantic conventions](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/general/trace.md)
 * for attributes and must be:
 * - Lowercase
 * - Use underscores for word separation
 * - Follow the format `<namespace>.<attribute>` (e.g. `file.size`)
 *
 * - Remark: As  Swift `enum` are not available in Objective-C, it uses a `class` with static properties, marked with `@objc` and `@objcMembers` instead.
 *           To reduce casting between `String` to `NSString` when using from Objective-C, it uses `NSString` instead of `String`.
 *           Eventually this should be replaced with a Swift `enum` when Objective-C compatibility is not needed anymore.
 * - Note: See [Sentry SDK development documentation](https://develop.sentry.dev/sdk/telemetry/traces/span-data-conventions/) for more information.
 */
@objcMembers @objc(SentrySpanDataKey)
class SentrySpanDataKey: NSObject {
    /// Used to set the number of bytes processed in a file span operation
    static let fileSize: NSString = "file.size"

    /// Used to set the path of the file in a file span operation
    static let filePath: NSString = "file.path"
}
