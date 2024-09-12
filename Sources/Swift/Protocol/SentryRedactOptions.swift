import Foundation

@objc
protocol SentryRedactOptions {
    var redactAllText: Bool { get }
    var redactAllImages: Bool { get }
    var redactViewTypes: [AnyClass] { get }
    var ignoreRedactViewTypes: [AnyClass] { get }
}
