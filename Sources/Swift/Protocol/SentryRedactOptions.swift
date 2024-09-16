import Foundation

@objc
protocol SentryRedactOptions {
    var redactAllText: Bool { get }
    var redactAllImages: Bool { get }
    var redactViewClasses: [AnyClass] { get }
    var ignoreViewClasses: [AnyClass] { get }
}
