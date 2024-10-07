import Foundation

@objc
protocol SentryRedactOptions {
    var maskAllText: Bool { get }
    var maskAllImages: Bool { get }
    var maskedViewClasses: [AnyClass] { get }
    var unmaskedViewClasses: [AnyClass] { get }
}
