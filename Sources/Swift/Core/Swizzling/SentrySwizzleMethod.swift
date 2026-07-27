import Foundation

/// Describes the Objective-C runtime signature expected by a typed swizzle.
///
/// `Receiver`, `Arguments`, and `Result` provide compile-time information to the typed swizzling
/// overloads. The runtime signature verifies that the selected Objective-C method uses a compatible
/// ABI before its implementation is replaced.
///
/// The receiver is the object that receives the Objective-C message. It is the instance exposed as
/// `self` inside the method. For example, the receiver of `URLSessionTask.resume()` is the specific
/// `URLSessionTask` being resumed.
struct SentrySwizzleMethod<Receiver: AnyObject, Arguments, Result> {
    /// The Objective-C selector represented by this descriptor.
    let selector: Selector

    /// The type of object that receives the Objective-C message and becomes the interceptor's first
    /// argument.
    let receiver: Receiver.Type

    /// The expected Objective-C runtime signature.
    let signature: Signature

    /// Creates a method descriptor for a selector, receiver, and Objective-C runtime signature.
    ///
    /// - Parameters:
    ///   - selector: The Objective-C selector represented by this descriptor.
    ///   - receiver: The type of object that receives the Objective-C message. Each intercepted
    ///     instance is passed to the replacement implementation as its first argument.
    ///   - signature: The Objective-C runtime signature required by the typed swizzle.
    init(selector: Selector, receiver: Receiver.Type, signature: Signature) {
        self.selector = selector
        self.receiver = receiver
        self.signature = signature
    }

    /// Describes the return and argument types in an Objective-C method signature.
    struct Signature: CustomStringConvertible {
        /// The method's return type.
        let returnType: ABIType

        /// The method's arguments, including the implicit receiver (`self`) and selector (`_cmd`)
        /// arguments that precede the method's explicit parameters at the Objective-C ABI level.
        let arguments: [ABIType]

        /// A compact representation of the complete Objective-C method signature.
        var description: String {
            ([returnType] + arguments).map(\.description).joined()
        }

        /// Determines whether this expected signature is ABI-compatible with an actual signature.
        ///
        /// - Parameter actual: The signature read from the Objective-C runtime.
        /// - Returns: `true` when the return type and every argument are ABI-compatible.
        func matches(_ actual: Signature) -> Bool {
            guard returnType.matches(actual.returnType), arguments.count == actual.arguments.count else {
                return false
            }
            return zip(arguments, actual.arguments).allSatisfy { expected, actual in
                expected.matches(actual)
            }
        }
    }

    /// A supported Objective-C ABI type used to validate a swizzled method signature.
    enum ABIType: CustomStringConvertible {
        /// The Objective-C `void` type.
        case void

        /// An Objective-C object reference.
        case object

        /// An Objective-C selector.
        case selector

        /// An Objective-C block.
        case block

        /// A signed integer represented by its size in bytes.
        case signedInteger(Int)

        /// A type that typed swizzling does not support.
        case unsupported

        /// Objective-C encoding markers with a fixed ABI representation.
        private static var fixedTypes: [Character: Self] {
            [
                "v": .void,
                "@": .object,
                ":": .selector
            ]
        }

        /// Objective-C signed integer encoding markers and their platform-specific sizes.
        private static var signedIntegerSizes: [Character: Int] {
            [
                "c": MemoryLayout<CChar>.size,
                "s": MemoryLayout<CShort>.size,
                "i": MemoryLayout<CInt>.size,
                "l": MemoryLayout<CLong>.size,
                "q": MemoryLayout<CLongLong>.size
            ]
        }

        /// A compact representation of the ABI type.
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

        /// Parses an Objective-C runtime type encoding into a supported ABI type.
        ///
        /// Type qualifiers are ignored because they do not change the calling convention checked by
        /// typed swizzling.
        ///
        /// - Parameter encoding: The type encoding returned by the Objective-C runtime.
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

        /// Determines whether two ABI types use compatible calling conventions.
        ///
        /// - Parameter actual: The type read from the Objective-C runtime.
        /// - Returns: `true` when both values represent the same supported ABI type.
        func matches(_ actual: ABIType) -> Bool {
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
}

extension SentrySwizzleMethod where Arguments == Void, Result == Void {
    /// Describes an Objective-C instance method that takes no explicit arguments and returns `Void`.
    ///
    /// - Parameters:
    ///   - selector: The Objective-C selector represented by this descriptor.
    ///   - receiver: The type of object that receives the Objective-C message and is passed to the
    ///     interceptor as its first argument.
    /// - Returns: A descriptor containing the selector and corresponding Objective-C runtime
    ///   signature.
    static func noArgumentVoid(_ selector: Selector, receiver: Receiver.Type) -> Self {
        .init(
            selector: selector,
            receiver: receiver,
            signature: .init(returnType: .void, arguments: [.object, .selector])
        )
    }
}
