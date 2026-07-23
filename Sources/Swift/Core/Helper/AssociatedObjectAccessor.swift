import Foundation

/// A type-safe helper for reading and writing Objective-C associated objects.
///
/// Use a stable `Key`, such as a static property, for each associated value.
///
/// Thread safety:
/// - The accessor does not synchronize access. Coordinate externally when multiple
///   threads may mutate the same associated storage.
///
/// Memory and lifetime:
/// - Keep the key alive while accessing its value because its identity is tied to
///   the address of its internal token.
/// - The `policy` controls the ownership semantics of the associated object. Use a
///   retain policy for strong references or another policy as appropriate.
///
/// - Warning: The encoded object must be compatible with the selected `policy`, and
///   `decode` must be able to reconstruct `T` from it.
struct AssociatedObjectAccessor<T> {
    // MARK: - Types

    /// A unique, type-safe key for an associated value.
    ///
    /// Each key owns a token with a stable address, so distinct keys do not collide.
    /// The generic type provides compile-time safety but does not affect Objective-C storage.
    /// The pointer is unretained to avoid ARC traffic and is valid only while the key is alive.
    struct Key {
        private final class Token {}

        /// Token with fixed pointer address
        private let token = Token()

        init() {}

        var pointer: UnsafeRawPointer {
            UnsafeRawPointer(Unmanaged.passUnretained(token).toOpaque())
        }
    }

    /// The result of decoding an associated object into `T`.
    ///
    /// An invalid value preserves the original object for diagnostics or migration.
    /// Consider adjusting the decoder or clearing incompatible stored values.
    enum Value {
        case valid(T)
        case invalid(Any)
    }

    // MARK: - Properties

    private let object: AnyObject
    private let key: Key
    private let policy: objc_AssociationPolicy
    private let decode: (Any) -> T?
    private let encode: (T) -> Any

    init(
        on object: AnyObject,
        key: Key,
        policy: objc_AssociationPolicy = .OBJC_ASSOCIATION_RETAIN_NONATOMIC,
        decode: @escaping (Any) -> T? = { $0 as? T },
        encode: @escaping (T) -> Any = { $0 }
    ) {
        self.object = object
        self.key = key
        self.policy = policy
        self.decode = decode
        self.encode = encode
    }

    var value: Value? {
        guard let rawValue = objc_getAssociatedObject(object, key.pointer) else {
            return nil
        }
        guard let value = decode(rawValue) else {
            return .invalid(rawValue)
        }
        return .valid(value)
    }

    func set(_ newValue: T?) {
        switch newValue {
        case .some(let value):
            objc_setAssociatedObject(object, key.pointer, encode(value), policy)
        case .none:
            objc_setAssociatedObject(object, key.pointer, nil, policy)
        }
    }
}
