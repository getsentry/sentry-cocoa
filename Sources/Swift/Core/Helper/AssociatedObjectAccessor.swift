import Foundation

/// A type-safe helper for reading and writing Objective-C associated objects.
///
/// AssociatedObjectAccessor wraps the untyped Objective-C associated-object APIs
/// (`objc_getAssociatedObject` / `objc_setAssociatedObject`) and provides:
/// - A strongly-typed interface via the generic `Value`.
/// - Pluggable encoding/decoding closures for transforming between Swift values
///   and the stored Objective-C object.
/// - An ergonomic way to access and mutate a single associated value on a specific
///   object using a stable `AssociatedObjectAccessor<T>.Key`.
///
/// Typical usage:
/// - Create or reuse a stable `AssociatedObjectAccessor<T>.Key` (e.g., a static property).
/// - Initialize an accessor for a specific object using that key.
/// - Read the value via `value`, which reports decoding success or failure as
///   `AssociatedObjectAccessor<T>.Value?`.
/// - Write the value via `set(_:)`, which stores or clears the associated object.
///
/// Thread safety:
/// - The accessor does not synchronize access. If multiple threads may mutate the
///   same associated storage, coordinate using external synchronization.
///
/// Memory and lifetime:
/// - The key’s identity is defined by its internal token’s address. Keep the key
///   alive for as long as you need to access the associated value.
/// - The `policy` controls the ownership semantics in Objective-C associated storage.
///   Choose `.OBJC_ASSOCIATION_RETAIN(_NONATOMIC)` for strong references, or other
///   policies as appropriate.
///
/// - Note: The `value` property reflects the raw presence of an associated object:
///   - `nil` means no associated object is set for the key.
///   - `.valid(T)` means an object exists and `decode` succeeded.
///   - `.invalid(Any)` means an object exists but could not be decoded into `T`.
///
/// - Warning: Ensure that the `encode` closure produces objects compatible with the
///   selected `policy`, and that `decode` is able to reconstruct `T` from those
///   objects.
///
/// - SeeAlso: `AssociatedObjectAccessor<T>.Key`, `AssociatedObjectAccessor<T>.Value`, `objc_getAssociatedObject`,
///            `objc_setAssociatedObject`, `objc_AssociationPolicy`.
struct AssociatedObjectAccessor<T> {
    // MARK: - Types

    /// A type-safe key used to access Objective-C associated objects on an instance.
    ///
    /// AssociatedObjectAccessor<T>.Key provides a unique identity for an associated value without
    /// requiring string literals or global pointers. Each instance creates an internal
    /// token object whose pointer address remains stable for the lifetime of the key,
    /// making it suitable for use with Objective-C runtime functions such as
    /// `objc_getAssociatedObject` and `objc_setAssociatedObject`.
    ///
    /// - Generic Parameter T: The Swift type of the associated value that this key
    ///   is intended to store and retrieve. This parameter is used for type-safety in
    ///   higher-level APIs and does not affect the underlying Objective-C storage.
    ///
    /// Usage:
    /// - Create a distinct key per associated property you want to store.
    /// - Keep the key alive (e.g., as a static or stored property) for as long as you
    ///   need to access the associated value, since the key’s identity is tied to the
    ///   lifetime of its internal token.
    /// - Pass the key’s stable `pointer` to Objective-C runtime APIs.
    ///
    /// Thread Safety:
    /// - The key itself is immutable after initialization. As with any use of associated
    ///   objects, ensure external synchronization if multiple threads mutate the same
    ///   associated storage.
    ///
    /// Notes:
    /// - Each key instance is unique. Two different `AssociatedObjectAccessor<T>.Key` instances
    ///   will not collide because they use distinct token objects with different addresses.
    /// - The `pointer` is derived using `Unmanaged.passUnretained` to avoid ARC retain
    ///   traffic and is safe as long as the key instance remains alive.
    struct Key {
        private final class Token {}

        /// Token with fixed pointer address
        private let token = Token()

        init() {}

        var pointer: UnsafeRawPointer {
            UnsafeRawPointer(Unmanaged.passUnretained(token).toOpaque())
        }
    }

    /// A typed wrapper representing the result of reading an Objective-C associated object.
    ///
    /// AssociatedObjectAccessor<T>.Value communicates whether the raw value stored in the Objective-C
    /// associated object storage could be successfully decoded into the expected Swift
    /// type `T`.
    ///
    /// Cases:
    /// - `valid(T)`: The associated object existed and was successfully decoded
    ///   (cast or transformed) into the expected `T`.
    /// - `invalid(Any)`: An associated object existed, but it could not be decoded
    ///   into `T`. The original raw object is preserved for diagnostics or
    ///   fallback handling.
    ///
    /// Typical usage:
    /// - Use this enum when fetching an associated value where type-safety is desired
    ///   but the underlying storage is untyped (Objective-C).
    /// - Switch on the enum to distinguish between a correctly typed value and a
    ///   mismatched value, enabling safe recovery paths.
    ///
    /// Example:
    /// ```swift
    /// switch accessor.value {
    /// case .some(.valid(let value)):
    ///     // Use the strongly-typed value
    /// case .some(.invalid(let raw)):
    ///     // Handle type mismatch, log or migrate
    /// case .none:
    ///     // No associated value set
    /// }
    /// ```
    ///
    /// Notes:
    /// - This enum does not itself perform decoding; it is the return type used by
    ///   higher-level accessors to report the outcome of decoding.
    /// - When encountering `.invalid`, consider whether you need to migrate legacy
    ///   data, adjust the decoding logic, or clear the associated object.
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
