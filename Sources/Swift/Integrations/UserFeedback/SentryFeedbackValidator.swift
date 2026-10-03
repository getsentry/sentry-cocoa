import Foundation

/// Validates user feedback message contents consistently across Swift and Objective-C call sites.
@objc(SentryFeedbackValidator)
@_spi(Private) public final class SentryFeedbackValidator: NSObject {
    /// Maximum number of Unicode scalars accepted in a feedback message.
    @objc public static let maximumMessageScalarCount = 4_096

    /// Returns whether a message is non-whitespace and within the scalar limit.
    @objc(isValidMessage:)
    public static func isValidMessage(_ message: String) -> Bool {
        guard message.unicodeScalars.count <= maximumMessageScalarCount else {
            return false
        }
        return hasNonWhitespaceCharacters(message)
    }

    /// Returns whether a message contains at least one scalar Python does not classify as whitespace.
    @objc(hasNonWhitespaceCharacters:)
    public static func hasNonWhitespaceCharacters(_ message: String) -> Bool {
        message.unicodeScalars.contains { scalar in
            !scalar.properties.isWhitespace && !(0x001C ... 0x001F).contains(scalar.value)
        }
    }
}
