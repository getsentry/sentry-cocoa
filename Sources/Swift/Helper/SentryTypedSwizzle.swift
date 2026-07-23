@_implementationOnly import _SentryPrivate
import Foundation
import ObjectiveC

final class SentrySwizzleKey {
    private final class Token {}

    private let token = Token()

    fileprivate var pointer: UnsafeRawPointer {
        UnsafeRawPointer(Unmanaged.passUnretained(token).toOpaque())
    }
}

struct SentrySwizzleMethod<Receiver: AnyObject, Arguments, Result> {
    fileprivate let receiver: Receiver.Type
    fileprivate let signature: SentrySwizzleMethodSignature

    fileprivate init(receiver: Receiver.Type, signature: SentrySwizzleMethodSignature) {
        self.receiver = receiver
        self.signature = signature
    }
}

extension SentrySwizzleMethod where Arguments == Void, Result == Void {
    static func noArgumentVoid(_ receiver: Receiver.Type) -> Self {
        .init(receiver: receiver, signature: .init(returnType: .void, arguments: [.object, .selector]))
    }
}

extension SentrySwizzleMethod where Arguments == URLSessionTask.State, Result == Void {
    static func urlSessionTaskState(_ receiver: Receiver.Type) -> Self {
        .init(receiver: receiver, signature: .init(returnType: .void, arguments: [.object, .selector, .signedInteger(MemoryLayout<Int>.size)]))
    }
}

typealias SentryDataTaskCompletionHandler = @convention(block) (Data?, URLResponse?, Error?) -> Void
typealias SentryDataTaskRequestArguments = (URLRequest, SentryDataTaskCompletionHandler?)
typealias SentryDataTaskURLArguments = (URL, SentryDataTaskCompletionHandler?)

extension SentrySwizzleMethod where Arguments == SentryDataTaskRequestArguments, Result == URLSessionDataTask {
    static func urlSessionDataTaskWithRequest(_ receiver: Receiver.Type) -> Self {
        .init(receiver: receiver, signature: .init(returnType: .object, arguments: [.object, .selector, .object, .block]))
    }
}

extension SentrySwizzleMethod where Arguments == SentryDataTaskURLArguments, Result == URLSessionDataTask {
    static func urlSessionDataTaskWithURL(_ receiver: Receiver.Type) -> Self {
        .init(receiver: receiver, signature: .init(returnType: .object, arguments: [.object, .selector, .object, .block]))
    }
}

enum SentryTypedSwizzle {
    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        _ selector: Selector,
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, Void, Void>,
        mode: SentrySwizzleMode,
        key: SentrySwizzleKey,
        interceptor: @escaping (Receiver, @escaping () -> Void) -> Void
    ) -> Bool {
        if let failure = validationFailure(selector, in: classToSwizzle, method: method) {
            reportValidationFailure(failure)
            return false
        }

        return SentrySwizzleWrapperHelper.swizzleInstanceMethod(
            selector,
            in: classToSwizzle,
            mode: mode,
            key: key.pointer
        ) { getOriginal in
            { receiver in
                guard let receiver = receiver as? Receiver else {
                    assertionFailure("Unexpected swizzle receiver for \(NSStringFromSelector(selector))")
                    return
                }

                interceptor(receiver) {
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector) -> Void).self
                    )
                    original(receiver, selector)
                }
            } as @convention(block) (AnyObject) -> Void
        }
    }

    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        _ selector: Selector,
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, URLSessionTask.State, Void>,
        mode: SentrySwizzleMode,
        key: SentrySwizzleKey,
        interceptor: @escaping (Receiver, URLSessionTask.State, @escaping (URLSessionTask.State) -> Void) -> Void
    ) -> Bool {
        if let failure = validationFailure(selector, in: classToSwizzle, method: method) {
            reportValidationFailure(failure)
            return false
        }

        return SentrySwizzleWrapperHelper.swizzleInstanceMethod(
            selector,
            in: classToSwizzle,
            mode: mode,
            key: key.pointer
        ) { getOriginal in
            { receiver, state in
                guard let receiver = receiver as? Receiver else {
                    assertionFailure("Unexpected swizzle receiver for \(NSStringFromSelector(selector))")
                    return
                }

                interceptor(receiver, state) { forwardedState in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, URLSessionTask.State) -> Void).self
                    )
                    original(receiver, selector, forwardedState)
                }
            } as @convention(block) (AnyObject, URLSessionTask.State) -> Void
        }
    }

    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        _ selector: Selector,
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentryDataTaskRequestArguments, URLSessionDataTask>,
        mode: SentrySwizzleMode,
        key: SentrySwizzleKey,
        interceptor: @escaping (
            Receiver,
            URLRequest,
            SentryDataTaskCompletionHandler?,
            @escaping (URLRequest, SentryDataTaskCompletionHandler?) -> URLSessionDataTask
        ) -> URLSessionDataTask
    ) -> Bool {
        if let failure = validationFailure(selector, in: classToSwizzle, method: method) {
            reportValidationFailure(failure)
            return false
        }

        return SentrySwizzleWrapperHelper.swizzleInstanceMethod(
            selector,
            in: classToSwizzle,
            mode: mode,
            key: key.pointer
        ) { getOriginal in
            { receiver, request, completionHandler in
                guard let receiver = receiver as? Receiver else {
                    preconditionFailure("Unexpected swizzle receiver for \(NSStringFromSelector(selector))")
                }

                return interceptor(receiver, request, completionHandler) { forwardedRequest, forwardedCompletionHandler in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (
                            AnyObject,
                            Selector,
                            URLRequest,
                            SentryDataTaskCompletionHandler?
                        ) -> URLSessionDataTask).self
                    )
                    return original(receiver, selector, forwardedRequest, forwardedCompletionHandler)
                }
            } as @convention(block) (
                AnyObject,
                URLRequest,
                SentryDataTaskCompletionHandler?
            ) -> URLSessionDataTask
        }
    }

    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        _ selector: Selector,
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentryDataTaskURLArguments, URLSessionDataTask>,
        mode: SentrySwizzleMode,
        key: SentrySwizzleKey,
        interceptor: @escaping (
            Receiver,
            URL,
            SentryDataTaskCompletionHandler?,
            @escaping (URL, SentryDataTaskCompletionHandler?) -> URLSessionDataTask
        ) -> URLSessionDataTask
    ) -> Bool {
        if let failure = validationFailure(selector, in: classToSwizzle, method: method) {
            reportValidationFailure(failure)
            return false
        }

        return SentrySwizzleWrapperHelper.swizzleInstanceMethod(
            selector,
            in: classToSwizzle,
            mode: mode,
            key: key.pointer
        ) { getOriginal in
            { receiver, url, completionHandler in
                guard let receiver = receiver as? Receiver else {
                    preconditionFailure("Unexpected swizzle receiver for \(NSStringFromSelector(selector))")
                }

                return interceptor(receiver, url, completionHandler) { forwardedURL, forwardedCompletionHandler in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (
                            AnyObject,
                            Selector,
                            URL,
                            SentryDataTaskCompletionHandler?
                        ) -> URLSessionDataTask).self
                    )
                    return original(receiver, selector, forwardedURL, forwardedCompletionHandler)
                }
            } as @convention(block) (
                AnyObject,
                URL,
                SentryDataTaskCompletionHandler?
            ) -> URLSessionDataTask
        }
    }

    static func validate<Receiver, Arguments, Result>(
        _ selector: Selector,
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, Arguments, Result>
    ) -> Bool {
        validationFailure(selector, in: classToSwizzle, method: method) == nil
    }

    static func validationFailure<Receiver, Arguments, Result>(
        _ selector: Selector,
        in classToSwizzle: AnyClass,
        method expectedMethod: SentrySwizzleMethod<Receiver, Arguments, Result>
    ) -> String? {
        guard classToSwizzle is Receiver.Type else {
            return "Swizzle receiver mismatch for \(NSStringFromClass(classToSwizzle)): expected \(NSStringFromClass(expectedMethod.receiver))"
        }

        guard let method = class_getInstanceMethod(classToSwizzle, selector) else {
            return "Swizzle method not found: \(NSStringFromClass(classToSwizzle)).\(NSStringFromSelector(selector))"
        }

        let actualSignature = SentrySwizzleMethodSignature(
            returnType: SentrySwizzleABIType(encoding: copyReturnType(of: method)),
            arguments: (0..<method_getNumberOfArguments(method)).map {
                SentrySwizzleABIType(encoding: copyArgumentType(of: method, at: $0))
            }
        )
        guard expectedMethod.signature.matches(actualSignature) else {
            return "Swizzle signature mismatch for \(NSStringFromClass(classToSwizzle)).\(NSStringFromSelector(selector)): expected \(expectedMethod.signature), actual \(actualSignature)"
        }

        return nil
    }

    private static func reportValidationFailure(_ message: String) {
        SentrySDKLog.error(message)
        assertionFailure(message)
    }

    private static func copyReturnType(of method: Method) -> String {
        let encoding = method_copyReturnType(method)
        defer { free(encoding) }
        return String(cString: encoding)
    }

    private static func copyArgumentType(of method: Method, at index: UInt32) -> String {
        guard let encoding = method_copyArgumentType(method, index) else {
            return ""
        }
        defer { free(encoding) }
        return String(cString: encoding)
    }
}

private struct SentrySwizzleMethodSignature: CustomStringConvertible {
    let returnType: SentrySwizzleABIType
    let arguments: [SentrySwizzleABIType]

    var description: String {
        ([returnType] + arguments).map(\.description).joined()
    }

    func matches(_ actual: SentrySwizzleMethodSignature) -> Bool {
        guard returnType.matches(actual.returnType), arguments.count == actual.arguments.count else {
            return false
        }
        return zip(arguments, actual.arguments).allSatisfy { expected, actual in
            expected.matches(actual)
        }
    }
}

private enum SentrySwizzleABIType: CustomStringConvertible {
    case void
    case object
    case selector
    case block
    case signedInteger(Int)
    case unsupported

    private static let fixedTypes: [Character: Self] = [
        "v": .void,
        "@": .object,
        ":": .selector
    ]

    private static let signedIntegerSizes: [Character: Int] = [
        "c": MemoryLayout<CChar>.size,
        "s": MemoryLayout<CShort>.size,
        "i": MemoryLayout<CInt>.size,
        "l": MemoryLayout<CLong>.size,
        "q": MemoryLayout<CLongLong>.size
    ]

    var description: String {
        switch self {
        case .void: return "v"
        case .object: return "@"
        case .selector: return ":"
        case .block: return "@?"
        case .signedInteger(let size): return "signed-int\(size * 8)"
        case .unsupported: return "?"
        }
    }

    init(encoding: String) {
        let normalized = encoding.drop(while: { "rnNoORV".contains($0) })

        if normalized.hasPrefix("@?") {
            self = .block
            return
        }

        guard let marker = normalized.first else {
            self = .unsupported
            return
        }

        if let fixedType = Self.fixedTypes[marker] {
            self = fixedType
        } else if let size = Self.signedIntegerSizes[marker] {
            self = .signedInteger(size)
        } else {
            self = .unsupported
        }
    }

    func matches(_ actual: SentrySwizzleABIType) -> Bool {
        switch (self, actual) {
        case (.void, .void), (.object, .object), (.selector, .selector), (.block, .block):
            return true
        case (.signedInteger(let expectedSize), .signedInteger(let actualSize)):
            return expectedSize == actualSize
        default:
            return false
        }
    }
}
