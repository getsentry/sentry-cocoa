// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCAttributeContent: NSObject {
    private let content: SentryAttributeContent

    internal init(_ content: SentryAttributeContent) {
        self.content = content
    }

    internal func toAttributeContent() -> SentryAttributeContent {
        content
    }

    @objc public static func string(_ value: String) -> SentryObjCAttributeContent {
        SentryObjCAttributeContent(.string(value))
    }

    @objc public static func boolean(_ value: Bool) -> SentryObjCAttributeContent {
        SentryObjCAttributeContent(.boolean(value))
    }

    @objc public static func integer(_ value: Int) -> SentryObjCAttributeContent {
        SentryObjCAttributeContent(.integer(value))
    }

    @objc public static func double(_ value: Double) -> SentryObjCAttributeContent {
        SentryObjCAttributeContent(.double(value))
    }

    @objc public static func stringArray(_ values: [String]) -> SentryObjCAttributeContent {
        SentryObjCAttributeContent(.stringArray(values))
    }

    @objc public static func booleanArray(_ values: [Bool]) -> SentryObjCAttributeContent {
        SentryObjCAttributeContent(.booleanArray(values))
    }

    @objc public static func integerArray(_ values: [Int]) -> SentryObjCAttributeContent {
        SentryObjCAttributeContent(.integerArray(values))
    }

    @objc public static func doubleArray(_ values: [Double]) -> SentryObjCAttributeContent {
        SentryObjCAttributeContent(.doubleArray(values))
    }

    @objc public var type: String {
        switch content {
        case .string: return "string"
        case .boolean: return "boolean"
        case .integer: return "integer"
        case .double: return "double"
        case .stringArray: return "string[]"
        case .booleanArray: return "boolean[]"
        case .integerArray: return "integer[]"
        case .doubleArray: return "double[]"
        @unknown default: return "unknown"
        }
    }

    @objc public var value: Any {
        switch content {
        case .string(let v): return v
        case .boolean(let v): return v
        case .integer(let v): return v
        case .double(let v): return v
        case .stringArray(let v): return v
        case .booleanArray(let v): return v
        case .integerArray(let v): return v
        case .doubleArray(let v): return v
        @unknown default: return NSNull()
        }
    }
}

// swiftlint:enable missing_docs
