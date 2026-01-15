import Foundation

/// Options for configuring what content should be redacted in session replays.
@objc
public protocol SentryRedactOptions {
    /// Whether all text content should be masked. Defaults to `true`.
    var maskAllText: Bool { get }
    /// Whether all images should be masked. Defaults to `true`.
    var maskAllImages: Bool { get }
    /// Additional view classes that should always be masked.
    var maskedViewClasses: [AnyClass] { get }
    /// View classes that should never be masked, overriding default masking behavior.
    var unmaskedViewClasses: [AnyClass] { get }
}

// swiftlint:disable missing_docs
@objcMembers
@_spi(Private) public final class SentryRedactDefaultOptions: NSObject, SentryRedactOptions {
    public var maskAllText: Bool = true
    public var maskAllImages: Bool = true
    public var maskedViewClasses: [AnyClass] = []
    public var unmaskedViewClasses: [AnyClass] = []
}
// swiftlint:enable missing_docs
