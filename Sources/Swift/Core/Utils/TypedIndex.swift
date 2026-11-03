/// An index whose phantom `Owner` type distinguishes the collection it references.
///
/// Indices with different owners cannot be interchanged, even when their underlying
/// values have the same type. Encoding and decoding use the value directly, without
/// an object wrapper, so typed indices retain the underlying wire representation.
/// This type does not validate bounds or associate an index with a particular collection instance.
struct TypedIndex<Owner, Value: Hashable & Codable>: Hashable, Codable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        value = try Value(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
