import Foundation

@objc
public protocol SentryRedactOptions {
    var maskAllText: Bool { get }
    var maskAllImages: Bool { get }
    var maskedViewClasses: [AnyClass] { get }
    var unmaskedViewClasses: [AnyClass] { get }

    /**
     * Enables the experimental view renderer used to redact rendered views.
     *
     * - Note: This method is an accessor for the ``SentryReplayOptions/enableExperimentalViewRenderer`` property.
     *         See ``SentryReplayOptions`` for more information.
     */
    var enableExperimentalViewRenderer: Bool { get }
}

@objcMembers
final class SentryRedactDefaultOptions: NSObject, SentryRedactOptions {
    var maskAllText: Bool = true
    var maskAllImages: Bool = true
    var maskedViewClasses: [AnyClass] = []
    var unmaskedViewClasses: [AnyClass] = []
    var enableExperimentalViewRenderer: Bool = false
}
