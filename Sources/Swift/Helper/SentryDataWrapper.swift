//
//  SentryDataWrapper.swift
//  Sentry
//
//  Created by Philip Niedertscheider on 12.12.24.
//  Copyright © 2024 Sentry. All rights reserved.
//

// swiftlint:disable
// TODO: remove this swiftlint:disable

/// A drop-in replacement for the standard ``Swift.Data`` but with automatic tracking for file I/O operations.
///
/// This structure is intended to resemble the same method signatures as of ``Swift.Data``.
@available(macOS 15, iOS 18.0, tvOS 15.0, *)
@frozen public struct SentryDataWrapper: Equatable, Hashable, RandomAccessCollection, MutableCollection, RangeReplaceableCollection, MutableDataProtocol, ContiguousBytes, Sendable {

    /// The wrapped data
    public private(set) var data: Data

    /// Convenience initializer
    public init(data: Data) {
        self.data = data
    }

    /// Initialize a `SentryDataWrapper` with copied memory content.
    ///
    ///
    /// - parameter bytes: A pointer to the memory. It will be copied.
    /// - parameter count: The number of bytes to copy.
    public init(bytes: UnsafeRawPointer, count: Int) {
        self.data = Data(bytes: bytes, count: count)
    }

    /// Initialize a `SentryDataWrapper` with copied memory content.
    ///
    /// - parameter buffer: A buffer pointer to copy. The size is calculated from `SourceType` and `buffer.count`.
    public init<SourceType>(buffer: UnsafeBufferPointer<SourceType>) {
        self.data = Data(buffer: buffer)
    }

    /// Initialize a `SentryDataWrapper` with copied memory content.
    ///
    /// - parameter buffer: A buffer pointer to copy. The size is calculated from `SourceType` and `buffer.count`.
    public init<SourceType>(buffer: UnsafeMutableBufferPointer<SourceType>) {
        self.data = Data(buffer: buffer)
    }

    /// Initialize a `SentryDataWrapper` with a repeating byte pattern
    ///
    /// - parameter repeatedValue: A byte to initialize the pattern
    /// - parameter count: The number of bytes the data initially contains initialized to the repeatedValue
    public init(repeating repeatedValue: UInt8, count: Int) {
        self.data = Data(repeating: repeatedValue, count: count)
    }

    /// Initialize a `SentryDataWrapper` with the specified size.
    ///
    /// This initializer doesn't necessarily allocate the requested memory right away. `SentryDataWrapper` allocates additional memory as needed, so `capacity` simply establishes the initial capacity. When it does allocate the initial memory, though, it allocates the specified amount.
    ///
    /// This method sets the `count` of the data to 0.
    ///
    /// If the capacity specified in `capacity` is greater than four memory pages in size, this may round the amount of requested memory up to the nearest full page.
    ///
    /// - parameter capacity: The size of the data.
    public init(capacity: Int) {
        self.data = Data(capacity: capacity)
    }

    /// Initialize a `SentryDataWrapper` with the specified count of zeroed bytes.
    ///
    /// - parameter count: The number of bytes the data initially contains.
    public init(count: Int) {
        self.data = Data(count: count)
    }

    /// Initialize an empty `SentryDataWrapper`.
    public init() {
        self.data = Data()
    }

    /// Initialize a `SentryDataWrapper` without copying the bytes.
    ///
    /// If the result is mutated and is not a unique reference, then the `SentryDataWrapper` will still follow copy-on-write semantics. In this case, the copy will use its own deallocator. Therefore, it is usually best to only use this initializer when you either enforce immutability with `let` or ensure that no other references to the underlying data are formed.
    /// - parameter bytes: A pointer to the bytes.
    /// - parameter count: The size of the bytes.
    /// - parameter deallocator: Specifies the mechanism to free the indicated buffer, or `.none`.
    public init(bytesNoCopy bytes: UnsafeMutableRawPointer, count: Int, deallocator: Data.Deallocator) {
        self.data = Data(bytesNoCopy: bytes, count: count, deallocator: deallocator)
    }

    /// Creates a new instance of a collection containing the elements of a
    /// sequence.
    ///
    /// - Parameter elements: The sequence of elements for the new collection.
    ///   `elements` must be finite.
    public init<S>(_ elements: S) where S: Sequence, S.Element == UInt8 {
        self.data = Data(elements)
    }

    @available(swift 4.2)
    @available(swift, deprecated: 5, message: "use `init(_:)` instead")
    public init<S>(bytes elements: S) where S: Sequence, S.Element == UInt8 {
        self.data = Data(bytes: elements)
    }

    public typealias ReadingOptions = NSData.ReadingOptions

    public typealias WritingOptions = NSData.WritingOptions

    /// Initialize a `SentryDataWrapper` with the contents of a `URL`.
    ///
    /// - parameter url: The `URL` to read.
    /// - parameter options: Options for the read operation. Default value is `[]`.
    /// - throws: An error in the Cocoa domain, if `url` cannot be read.
    public init(contentsOf url: URL, options: Data.ReadingOptions = []) throws {
        // TODO: start file.read via static tracker
        self.data = try Data(contentsOf: url, options: options)
        // TODO: end file.read via static tracker
    }

    /// Prepares the collection to store the specified number of elements, when
    /// doing so is appropriate for the underlying type.
    ///
    /// If you are adding a known number of elements to a collection, use this
    /// method to avoid multiple reallocations. A type that conforms to
    /// `RangeReplaceableCollection` can choose how to respond when this method
    /// is called. Depending on the type, it may make sense to allocate more or
    /// less storage than requested, or to take no action at all.
    ///
    /// - Parameter n: The requested number of elements to store.
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        self.data.reserveCapacity(minimumCapacity)
    }

    /// The number of bytes in the data.
    public var count: Int {
        return self.data.count
    }

    /// A `BidirectionalCollection` of `DataProtocol` elements which compose a
    /// discontiguous buffer of memory.  Each region is a contiguous buffer of
    /// bytes.
    ///
    /// The sum of the lengths of the associated regions must equal `self.count`
    /// (such that iterating `regions` and iterating `self` produces the same
    /// sequence of indices in the same number of index advancements).
    public var regions: CollectionOfOne<Data> { 
        return self.data.regions
    }

    /// Access the bytes in the data.
    ///
    /// - warning: The byte pointer argument should not be stored and used outside of the lifetime of the call to the closure.
    @available(swift, deprecated: 5, message: "use `withUnsafeBytes<R>(_: (UnsafeRawBufferPointer) throws -> R) rethrows -> R` instead")
    public func withUnsafeBytes<ResultType, ContentType>(_ body: (UnsafePointer<ContentType>) throws -> ResultType) rethrows -> ResultType {
        return try self.data.withUnsafeBytes(body)
    }

    /// Calls the given closure with the contents of underlying storage.
    ///
    /// - note: Calling `withUnsafeBytes` multiple times does not guarantee that
    ///         the same buffer pointer will be passed in every time.
    /// - warning: The buffer argument to the body should not be stored or used
    ///            outside of the lifetime of the call to the closure.
    public func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        return try self.data.withUnsafeBytes(body)
    }

    /// Executes a closure on the sequence’s contiguous storage.
    ///
    /// This method calls `body(buffer)`, where `buffer` is a pointer to the
    /// collection’s contiguous storage. If the contiguous storage doesn't exist,
    /// the collection creates it. If the collection doesn’t support an internal
    /// representation in a form of contiguous storage, the method doesn’t call
    /// `body` --- it immediately returns `nil`.
    ///
    /// The optimizer can often eliminate bounds- and uniqueness-checking
    /// within an algorithm. When that fails, however, invoking the same
    /// algorithm on the `buffer` argument may let you trade safety for speed.
    ///
    /// Successive calls to this method may provide a different pointer on each
    /// call. Don't store `buffer` outside of this method.
    ///
    /// A `Collection` that provides its own implementation of this method
    /// must provide contiguous storage to its elements in the same order
    /// as they appear in the collection. This guarantees that it's possible to
    /// generate contiguous mutable storage to any of its subsequences by slicing
    /// `buffer` with a range formed from the distances to the subsequence's
    /// `startIndex` and `endIndex`, respectively.
    ///
    /// - Parameters:
    ///   - body: A closure that receives an `UnsafeBufferPointer` to the
    ///     sequence's contiguous storage.
    /// - Returns: The value returned from `body`, unless the sequence doesn't
    ///   support contiguous storage, in which case the method ignores `body` and
    ///   returns `nil`.
    public func withContiguousStorageIfAvailable<ResultType>(_ body: (_ buffer: UnsafeBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType? {
        return try self.data.withContiguousStorageIfAvailable(body)
    }

    /// Mutate the bytes in the data.
    ///
    /// This function assumes that you are mutating the contents.
    /// - warning: The byte pointer argument should not be stored and used outside of the lifetime of the call to the closure.
    @available(swift, deprecated: 5, message: "use `withUnsafeMutableBytes<R>(_: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R` instead")
    public mutating func withUnsafeMutableBytes<ResultType, ContentType>(_ body: (UnsafeMutablePointer<ContentType>) throws -> ResultType) rethrows -> ResultType {
        return try self.data.withUnsafeMutableBytes(body)
    }

    public mutating func withUnsafeMutableBytes<ResultType>(_ body: (UnsafeMutableRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        return try self.data.withUnsafeMutableBytes(body)
    }

    /// Copy the contents of the data to a pointer.
    ///
    /// - parameter pointer: A pointer to the buffer you wish to copy the bytes into.
    /// - parameter count: The number of bytes to copy.
    /// - warning: This method does not verify that the contents at pointer have enough space to hold `count` bytes.
    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, count: Int) {
        self.data.copyBytes(to: pointer, count: count)
    }

    /// Copy a subset of the contents of the data to a pointer.
    ///
    /// - parameter pointer: A pointer to the buffer you wish to copy the bytes into.
    /// - parameter range: The range in the `SentryDataWrapper` to copy.
    /// - warning: This method does not verify that the contents at pointer have enough space to hold the required number of bytes.
    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, from range: Range<Data.Index>) {
        self.data.copyBytes(to: pointer, from: range)
    }

    ///
    /// This function copies the bytes in `range` from the data into the buffer. If the count of the `range` is greater than `MemoryLayout<DestinationType>.stride * buffer.count` then the first N bytes will be copied into the buffer.
    /// - precondition: The range must be within the bounds of the data. Otherwise `fatalError` is called.
    /// - parameter buffer: A buffer to copy the data into.
    /// - parameter range: A range in the data to copy into the buffer. If the range is empty, this function will return 0 without copying anything. If the range is nil, as much data as will fit into `buffer` is copied.
    /// - returns: Number of bytes copied into the destination buffer.
    public func copyBytes<DestinationType>(to buffer: UnsafeMutableBufferPointer<DestinationType>, from range: Range<Data.Index>? = nil) -> Int {
        return self.data.copyBytes(to: buffer, from: range)
    }

    /// Enumerate the contents of the data.
    ///
    /// In some cases, (for example, a `SentryDataWrapper` backed by a `dispatch_data_t`, the bytes may be stored discontinuously. In those cases, this function invokes the closure for each contiguous region of bytes.
    /// - parameter block: The closure to invoke for each region of data. You may stop the enumeration by setting the `stop` parameter to `true`.
    @available(swift, deprecated: 5, message: "use `regions` or `for-in` instead")
    public func enumerateBytes(_ block: (_ buffer: UnsafeBufferPointer<UInt8>, _ byteIndex: Data.Index, _ stop: inout Bool) -> Void) {
        self.data.enumerateBytes(block)
    }

    public mutating func append(_ bytes: UnsafePointer<UInt8>, count: Int) {
        self.data.append(bytes, count: count)
    }

    public mutating func append(_ other: Data) {
        self.data.append(other)
    }

    /// Append a buffer of bytes to the data.
    ///
    /// - parameter buffer: The buffer of bytes to append. The size is calculated from `SourceType` and `buffer.count`.
    public mutating func append<SourceType>(_ buffer: UnsafeBufferPointer<SourceType>) {
        self.data.append(buffer)
    }

    public mutating func append(contentsOf bytes: [UInt8]) {
        self.data.append(contentsOf: bytes)
    }

    /// Adds the elements of a sequence or collection to the end of this
    /// collection.
    ///
    /// The collection being appended to allocates any additional necessary
    /// storage to hold the new elements.
    ///
    /// The following example appends the elements of a `Range<Int>` instance to
    /// an array of integers:
    ///
    ///     var numbers = [1, 2, 3, 4, 5]
    ///     numbers.append(contentsOf: 10...15)
    ///     print(numbers)
    ///     // Prints "[1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15]"
    ///
    /// - Parameter newElements: The elements to append to the collection.
    ///
    /// - Complexity: O(*m*), where *m* is the length of `newElements`.
    public mutating func append<S>(contentsOf elements: S) where S: Sequence, S.Element == UInt8 {
        self.data.append(contentsOf: elements)
    }

    /// Set a region of the data to `0`.
    ///
    /// If `range` exceeds the bounds of the data, then the data is resized to fit.
    /// - parameter range: The range in the data to set to `0`.
    public mutating func resetBytes(in range: Range<Data.Index>) {
        self.data.resetBytes(in: range)
    }

    /// Replace a region of bytes in the data with new data.
    ///
    /// This will resize the data if required, to fit the entire contents of `SentryDataWrapper`.
    ///
    /// - precondition: The bounds of `subrange` must be valid indices of the collection.
    /// - parameter subrange: The range in the data to replace. If `subrange.lowerBound == data.count && subrange.count == 0` then this operation is an append.
    /// - parameter data: The replacement data.
    public mutating func replaceSubrange(_ subrange: Range<Data.Index>, with data: Data) {
        self.data.replaceSubrange(subrange, with: data)
    }

    /// Replace a region of bytes in the data with new bytes from a buffer.
    ///
    /// This will resize the data if required, to fit the entire contents of `buffer`.
    ///
    /// - precondition: The bounds of `subrange` must be valid indices of the collection.
    /// - parameter subrange: The range in the data to replace.
    /// - parameter buffer: The replacement bytes.
    public mutating func replaceSubrange<SourceType>(_ subrange: Range<Data.Index>, with buffer: UnsafeBufferPointer<SourceType>) {
        self.data.replaceSubrange(subrange, with: buffer)
    }

    /// Replace a region of bytes in the data with new bytes from a collection.
    ///
    /// This will resize the data if required, to fit the entire contents of `newElements`.
    ///
    /// - precondition: The bounds of `subrange` must be valid indices of the collection.
    /// - parameter subrange: The range in the data to replace.
    /// - parameter newElements: The replacement bytes.
    public mutating func replaceSubrange<ByteCollection>(_ subrange: Range<Data.Index>, with newElements: ByteCollection) where ByteCollection: Collection, ByteCollection.Element == UInt8 {
        self.data.replaceSubrange(subrange, with: newElements)
    }

    public mutating func replaceSubrange(_ subrange: Range<Data.Index>, with bytes: UnsafeRawPointer, count cnt: Int) {
        self.data.replaceSubrange(subrange, with: bytes, count: cnt)
    }

    /// Return a new copy of the data in a specified range.
    ///
    /// - parameter range: The range to copy.
    public func subdata(in range: Range<Data.Index>) -> Data {
        return self.data.subdata(in: range)
    }

    /// Write the contents of the `SentryDataWrapper` to a location.
    ///
    /// - parameter url: The location to write the data into.
    /// - parameter options: Options for writing the data. Default value is `[]`.
    /// - throws: An error in the Cocoa domain, if there is an error writing to the `URL`.
    public func write(to url: URL, options: Data.WritingOptions = []) throws {
        // TODO: begin file.write via static tracker
        try self.data.write(to: url, options: options)
        // TODO: end file.write via static tracker
    }

    /// The hash value for the data.
    public func hash(into hasher: inout Hasher) {
        self.data.hash(into: &hasher)
    }

    public func advanced(by amount: Int) -> Data {
        return self.data.advanced(by: amount)
    }

    /// Sets or returns the byte at the specified index.
    public subscript(index: Data.Index) -> UInt8 {
        get {
            return self.data[index]
        }
        set {
            self.data[index] = newValue
        }
    }

    /// Accesses a contiguous subrange of the collection's elements.
    ///
    /// The accessed slice uses the same indices for the same elements as the
    /// original collection uses. Always use the slice's `startIndex` property
    /// instead of assuming that its indices start at a particular value.
    ///
    /// This example demonstrates getting a slice of an array of strings, finding
    /// the index of one of the strings in the slice, and then using that index
    /// in the original array.
    ///
    ///     let streets = ["Adams", "Bryant", "Channing", "Douglas", "Evarts"]
    ///     let streetsSlice = streets[2 ..< streets.endIndex]
    ///     print(streetsSlice)
    ///     // Prints "["Channing", "Douglas", "Evarts"]"
    ///
    ///     let index = streetsSlice.firstIndex(of: "Evarts")    // 4
    ///     print(streets[index!])
    ///     // Prints "Evarts"
    ///
    /// - Parameter bounds: A range of the collection's indices. The bounds of
    ///   the range must be valid indices of the collection.
    ///
    /// - Complexity: O(1)
    public subscript(bounds: Range<Data.Index>) -> Data {
        get {
            return self.data[bounds]
        }
        set {
            self.data[bounds] = newValue
        }
    }

    public subscript<R>(rangeExpression: R) -> Data where R: RangeExpression, R.Bound: FixedWidthInteger {
        get {
            self.data[rangeExpression]
        }
        set {
            self.data[rangeExpression] = newValue
        }
    }

    /// The start `Index` in the data.
    public var startIndex: Data.Index { 
        return self.data.startIndex
     }

    /// The end `Index` into the data.
    ///
    /// This is the "one-past-the-end" position, and will always be equal to the `count`.
    public var endIndex: Data.Index { 
        return self.data.endIndex
     }

    /// Returns the position immediately before the given index.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be greater than
    ///   `startIndex`.
    /// - Returns: The index value immediately before `i`.
    public func index(before i: Data.Index) -> Data.Index {
        return self.data.index(before: i)
    }

    /// Returns the position immediately after the given index.
    ///
    /// The successor of an index must be well defined. For an index `i` into a
    /// collection `c`, calling `c.index(after: i)` returns the same index every
    /// time.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Data.Index) -> Data.Index {
        return self.data.index(after: i)
    }

    /// The indices that are valid for subscripting the collection, in ascending
    /// order.
    ///
    /// A collection's `indices` property can hold a strong reference to the
    /// collection itself, causing the collection to be nonuniquely referenced.
    /// If you mutate the collection while iterating over its indices, a strong
    /// reference can result in an unexpected copy of the collection. To avoid
    /// the unexpected copy, use the `index(after:)` method starting with
    /// `startIndex` to produce indices instead.
    ///
    ///     var c = MyFancyCollection([10, 20, 30, 40, 50])
    ///     var i = c.startIndex
    ///     while i != c.endIndex {
    ///         c[i] /= 5
    ///         i = c.index(after: i)
    ///     }
    ///     // c == MyFancyCollection([2, 4, 6, 8, 10])
    public var indices: Range<Int> { 
        return self.data.indices
     }

    /// An iterator over the contents of the data.
    ///
    /// The iterator will increment byte-by-byte.
    public func makeIterator() -> Data.Iterator {
        return self.data.makeIterator()
    }

    /// Find the given `SentryDataWrapper` in the content of this `SentryDataWrapper`.
    ///
    /// - parameter dataToFind: The data to be searched for.
    /// - parameter options: Options for the search. Default value is `[]`.
    /// - parameter range: The range of this data in which to perform the search. Default value is `nil`, which means the entire content of this data.
    /// - returns: A `Range` specifying the location of the found data, or nil if a match could not be found.
    /// - precondition: `range` must be in the bounds of the Data.
    public func range(of dataToFind: Data, options: Data.SearchOptions = [], in range: Range<Data.Index>? = nil) -> Range<Data.Index>? {
        return self.data.range(of: dataToFind, options: options, in: range)
    }   

    /// Returns `true` if the two `SentryDataWrapper` arguments are equal.
    public static func == (d1: SentryDataWrapper, d2: SentryDataWrapper) -> Bool {
        return d1.data == d2.data
    }

    /// The hash value.
    ///
    /// Hash values are not guaranteed to be equal across different executions of
    /// your program. Do not save hash values to use during a future execution.
    ///
    /// - Important: `hashValue` is deprecated as a `Hashable` requirement. To
    ///   conform to `Hashable`, implement the `hash(into:)` requirement instead.
    ///   The compiler provides an implementation for `hashValue` for you.
    public var hashValue: Int { 
        return self.data.hashValue
    }

    /// Initialize a `SentryDataWrapper` from a Base-64 encoded String using the given options.
    ///
    /// Returns nil when the input is not recognized as valid Base-64.
    /// - parameter base64String: The string to parse.
    /// - parameter options: Encoding options. Default value is `[]`.
    public init?(base64Encoded base64String: String, options: Data.Base64DecodingOptions = []) {
        guard let data = Data(base64Encoded: base64String, options: options) else {
            return nil
        }
        self.data = data
    }

    /// Initialize a `SentryDataWrapper` from a Base-64, UTF-8 encoded `SentryDataWrapper`.
    ///
    /// Returns nil when the input is not recognized as valid Base-64.
    ///
    /// - parameter base64Data: Base-64, UTF-8 encoded input data.
    /// - parameter options: Decoding options. Default value is `[]`.
    public init?(base64Encoded base64Data: Data, options: Data.Base64DecodingOptions = []) {
        guard let data = Data(base64Encoded: base64Data, options: options) else {
            return nil
        }
        self.data = data
    }

    /// Returns a Base-64 encoded string.
    ///
    /// - parameter options: The options to use for the encoding. Default value is `[]`.
    /// - returns: The Base-64 encoded string.
    public func base64EncodedString(options: Data.Base64EncodingOptions = []) -> String {
        return self.data.base64EncodedString(options: options)
    }

    /// Returns a Base-64 encoded `SentryDataWrapper`.
    ///
    /// - parameter options: The options to use for the encoding. Default value is `[]`.
    /// - returns: The Base-64 encoded data.
    public func base64EncodedData(options: Data.Base64EncodingOptions = []) -> Data {
        return self.data.base64EncodedData(options: options)
    }

    /// Initialize a `SentryDataWrapper` by adopting a reference type.
    ///
    /// You can use this initializer to create a `struct Data` that wraps a `class NSData`. `struct Data` will use the `class NSData` for all operations. Other initializers (including casting using `as Data`) may choose to hold a reference or not, based on a what is the most efficient representation.
    ///
    /// If the resulting value is mutated, then `SentryDataWrapper` will invoke the `mutableCopy()` function on the reference to copy the contents. You may customize the behavior of that function if you wish to return a specialized mutable subclass.
    ///
    /// - parameter reference: The instance of `NSData` that you wish to wrap. This instance will be copied by `struct Data`.
    public init(referencing reference: NSData) {
        self.data = Data(referencing: reference)
    }
}

@available(macOS 15, iOS 18.0, tvOS 15.0, *)
extension SentryDataWrapper: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {

    /// A human-readable description for the data.
    public var description: String {
        self.data.description
    }

    /// A human-readable debug description for the data.
    public var debugDescription: String {
        self.data.debugDescription
    }

    /// The custom mirror for this instance.
    ///
    /// If this type has value semantics, the mirror should be unaffected by
    /// subsequent mutations of the instance.
    public var customMirror: Mirror {
        self.data.customMirror
    }
}

@available(macOS 15, iOS 18.0, tvOS 15.0, *)
extension SentryDataWrapper: Codable {

    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: any Decoder) throws {
        self.data = try Data(from: decoder)
    }

    /// Encodes this value into the given encoder.
    ///
    /// If the value fails to encode anything, `encoder` will encode an empty
    /// keyed container in its place.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: any Encoder) throws {
        try self.data.encode(to: encoder)
    }
}
