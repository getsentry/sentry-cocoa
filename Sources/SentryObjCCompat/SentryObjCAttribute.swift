// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCAttribute) public final class SentryObjCAttribute: NSObject {
    internal let wrapped: SentryAttribute

    internal init(_ wrapped: SentryAttribute) {
        self.wrapped = wrapped
    }

    @objc public init(string value: String) {
        self.wrapped = SentryAttribute(string: value)
    }

    @objc public init(boolean value: Bool) {
        self.wrapped = SentryAttribute(boolean: value)
    }

    @objc public init(integer value: Int) {
        self.wrapped = SentryAttribute(integer: value)
    }

    @objc public init(double value: Double) {
        self.wrapped = SentryAttribute(double: value)
    }

    @objc public init(float value: Float) {
        self.wrapped = SentryAttribute(float: value)
    }

    @objc public init(stringArray values: [String]) {
        self.wrapped = SentryAttribute(stringArray: values)
    }

    @objc public init(booleanArray values: [Bool]) {
        self.wrapped = SentryAttribute(booleanArray: values)
    }

    @objc public init(integerArray values: [Int]) {
        self.wrapped = SentryAttribute(integerArray: values)
    }

    @objc public init(doubleArray values: [Double]) {
        self.wrapped = SentryAttribute(doubleArray: values)
    }

    @objc public init(floatArray values: [Float]) {
        self.wrapped = SentryAttribute(floatArray: values)
    }

    @objc public var type: String {
        wrapped.type
    }

    @objc public var value: Any {
        wrapped.value
    }
}

// swiftlint:enable missing_docs
