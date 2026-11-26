import Foundation

/// An ID that belongs to one kind of thing, so it can't be mixed up with the IDs of another kind
/// or with any other value of its raw type.
///
/// `Owner` is the type the ID identifies and takes no part in the value; it only tells the IDs of
/// different owners apart at compile time. An ID is turned into its raw value only where it is
/// stored or sent, and turned back into an ID only where that store is read:
///
/// ```swift
/// struct Run {
///     typealias ID = SentryIdentifier<Run, String>
///     let id: ID
/// }
/// ```
@_spi(Private) public struct SentryIdentifier<Owner, RawValue: Hashable>: Hashable, RawRepresentable, CustomStringConvertible {
    /// The ID as the stores keep it.
    public let rawValue: RawValue

    /// - Parameter rawValue: The ID as a store kept it.
    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }

    /// The raw value, so logs print the ID itself.
    public var description: String {
        String(describing: rawValue)
    }
}

/// An ID is stored as its raw value alone, so a store that kept the raw value before reads the
/// same data, and a type that holds an ID gets its `Codable` conformance synthesized.
extension SentryIdentifier: Decodable where RawValue: Decodable {
    /// Reads the ID from its raw value.
    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(RawValue.self))
    }
}

extension SentryIdentifier: Encodable where RawValue: Encodable {
    /// Writes the ID as its raw value.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
