//
//  SentryDataWrapper.swift
//  Sentry
//
//  Created by Philip Niedertscheider on 12.12.24.
//  Copyright © 2024 Sentry. All rights reserved.
//

/// A drop-in replacement for the standard ``Swift.Data`` but with automatic tracking for file I/O operations.
///
/// This structure is intended to resemble the same method signatures as of ``Swift.Data``.
@available(iOS 18, macOS 15, tvOS 18, *)
@frozen public struct SentryDataWrapper: Equatable, Hashable, RandomAccessCollection, MutableCollection, RangeReplaceableCollection, MutableDataProtocol, ContiguousBytes, Sendable {

    /// The wrapped data
    public private(set) var data: Data

    /// Convenience initializer to wrap an existing `Data` instance.
    public init(data: Data) {
        self.data = data
    }

    /// See `Data.init(bytes:count:)`
    public init(bytes: UnsafeRawPointer, count: Int) {
        self.data = Data(bytes: bytes, count: count)
    }

    /// See `Data.init(buffer:)`
    public init<SourceType>(buffer: UnsafeBufferPointer<SourceType>) {
        self.data = Data(buffer: buffer)
    }

    /// See `Data.init(buffer:)`
    public init<SourceType>(buffer: UnsafeMutableBufferPointer<SourceType>) {
        self.data = Data(buffer: buffer)
    }

    /// See `Data.init(repeating:count:)`
    public init(repeating repeatedValue: UInt8, count: Int) {
        self.data = Data(repeating: repeatedValue, count: count)
    }

    /// See `Data.init(capacity:)`
    public init(capacity: Int) {
        self.data = Data(capacity: capacity)
    }

    /// See `Data.init(count:)`
    public init(count: Int) {
        self.data = Data(count: count)
    }

    /// See `Data.init()`
    public init() {
        self.data = Data()
    }

    /// See `Data.init(bytesNoCopy:count:deallocator:)`
    public init(bytesNoCopy bytes: UnsafeMutableRawPointer, count: Int, deallocator: Data.Deallocator) {
        self.data = Data(bytesNoCopy: bytes, count: count, deallocator: deallocator)
    }

    /// See `Data.init(_:)`
    public init<S>(_ elements: S) where S: Sequence, S.Element == UInt8 {
        self.data = Data(elements)
    }

    /// See `Data.init(bytes:)`
    @available(swift 4.2)
    @available(swift, deprecated: 5, message: "use `init(_:)` instead")
    public init<S>(bytes elements: S) where S: Sequence, S.Element == UInt8 {
        self.data = Data(bytes: elements)
    }

    /// See `Data.init(contentsOf:options:)`
    public init(contentsOf url: URL, options: Data.ReadingOptions = []) throws {
        // start file.read via static tracker
        self.data = try Data(contentsOf: url, options: options)
        // end file.read via static tracker
    }

    /// See `Data.reserveCapacity(_:)`
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        self.data.reserveCapacity(minimumCapacity)
    }

    /// See `Data.count`
    public var count: Int {
        return self.data.count
    }

    /// See `Data.regions`
    public var regions: CollectionOfOne<Data> { 
        return self.data.regions
    }

    /// See `Data.withUnsafeBytes<R>(_: (UnsafeRawBufferPointer) throws -> R) rethrows -> R`
    @available(swift, deprecated: 5, message: "use `withUnsafeBytes<R>(_: (UnsafeRawBufferPointer) throws -> R) rethrows -> R` instead")
    public func withUnsafeBytes<ResultType, ContentType>(_ body: (UnsafePointer<ContentType>) throws -> ResultType) rethrows -> ResultType {
        return try self.data.withUnsafeBytes(body)
    }

    /// See `Data.withUnsafeBytes<R>(_: (UnsafeRawBufferPointer) throws -> R) rethrows -> R`
    public func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        return try self.data.withUnsafeBytes(body)
    }

    /// See `Data.withContiguousStorageIfAvailable<ResultType>(_ body: (_ buffer: UnsafeBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType?`
    public func withContiguousStorageIfAvailable<ResultType>(_ body: (_ buffer: UnsafeBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType? {
        return try self.data.withContiguousStorageIfAvailable(body)
    }

    /// See `Data.withUnsafeMutableBytes<R>(_: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R`
    public mutating func withUnsafeMutableBytes<ResultType, ContentType>(_ body: (UnsafeMutablePointer<ContentType>) throws -> ResultType) rethrows -> ResultType {
        return try self.data.withUnsafeMutableBytes(body)
    }

    /// See `Data.withUnsafeMutableBytes<R>(_: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R`
    public mutating func withUnsafeMutableBytes<ResultType>(_ body: (UnsafeMutableRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        return try self.data.withUnsafeMutableBytes(body)
    }

    /// See `Data.copyBytes(to:count:)`
    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, count: Int) {
        self.data.copyBytes(to: pointer, count: count)
    }

    /// See `Data.copyBytes(to:from:)`
    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, from range: Range<Data.Index>) {
        self.data.copyBytes(to: pointer, from: range)
    }

    /// See `Data.copyBytes(to:from:)`
    public func copyBytes<DestinationType>(to buffer: UnsafeMutableBufferPointer<DestinationType>, from range: Range<Data.Index>? = nil) -> Int {
        return self.data.copyBytes(to: buffer, from: range)
    }

    /// See `Data.enumerateBytes(_:)`
    @available(swift, deprecated: 5, message: "use `regions` or `for-in` instead")
    public func enumerateBytes(_ block: (_ buffer: UnsafeBufferPointer<UInt8>, _ byteIndex: Data.Index, _ stop: inout Bool) -> Void) {
        self.data.enumerateBytes(block)
    }

    /// See `Data.append(_:)`
    public mutating func append(_ bytes: UnsafePointer<UInt8>, count: Int) {
        self.data.append(bytes, count: count)
    }

    /// See `Data.append(_:)`
    public mutating func append(_ other: Data) {
        self.data.append(other)
    }

    /// See `Data.append<SourceType>(_ buffer: UnsafeBufferPointer<SourceType>)`
    public mutating func append<SourceType>(_ buffer: UnsafeBufferPointer<SourceType>) {
        self.data.append(buffer)
    }

    /// See `Data.append(contentsOf:)`
    public mutating func append(contentsOf bytes: [UInt8]) {
        self.data.append(contentsOf: bytes)
    }

    /// See `Data.append(contentsOf:)`
    public mutating func append<S>(contentsOf elements: S) where S: Sequence, S.Element == UInt8 {
        self.data.append(contentsOf: elements)
    }

    /// See `Data.resetBytes(in:)`
    public mutating func resetBytes(in range: Range<Data.Index>) {
        self.data.resetBytes(in: range)
    }

    /// See `Data.replaceSubrange(_:with:)`
    public mutating func replaceSubrange(_ subrange: Range<Data.Index>, with data: Data) {
        self.data.replaceSubrange(subrange, with: data)
    }

    /// See `Data.replaceSubrange(_:with:)`
    public mutating func replaceSubrange<SourceType>(_ subrange: Range<Data.Index>, with buffer: UnsafeBufferPointer<SourceType>) {
        self.data.replaceSubrange(subrange, with: buffer)
    }

    /// See `Data.replaceSubrange<ByteCollection>(_ subrange: Range<Data.Index>, with newElements: ByteCollection) where ByteCollection: Collection, ByteCollection.Element == UInt8`
    public mutating func replaceSubrange<ByteCollection>(_ subrange: Range<Data.Index>, with newElements: ByteCollection) where ByteCollection: Collection, ByteCollection.Element == UInt8 {
        self.data.replaceSubrange(subrange, with: newElements)
    }

    /// See `Data.replaceSubrange(_:with:)`
    public mutating func replaceSubrange(_ subrange: Range<Data.Index>, with bytes: UnsafeRawPointer, count cnt: Int) {
        self.data.replaceSubrange(subrange, with: bytes, count: cnt)
    }

    /// See `Data.subdata(in:)`
    public func subdata(in range: Range<Data.Index>) -> Data {
        return self.data.subdata(in: range)
    }

    /// See `Data.write(to:options:)`
    public func write(to url: URL, options: Data.WritingOptions = []) throws {
        // begin file.write via static tracker
        try self.data.write(to: url, options: options)
        // end file.write via static tracker
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

    /// See `Data.subscript(bounds:)`
    public subscript(bounds: Range<Data.Index>) -> Data {
        get {
            return self.data[bounds]
        }
        set {
            self.data[bounds] = newValue
        }
    }

    /// See `Data.subscript<R>(rangeExpression: R) -> Data where R: RangeExpression, R.Bound: FixedWidthInteger`
    public subscript<R>(rangeExpression: R) -> Data where R: RangeExpression, R.Bound: FixedWidthInteger {
        get {
            self.data[rangeExpression]
        }
        set {
            self.data[rangeExpression] = newValue
        }
    }

    /// See `Data.startIndex`
    public var startIndex: Data.Index { 
        return self.data.startIndex
     }

    /// See `Data.endIndex`
    public var endIndex: Data.Index { 
        return self.data.endIndex
     }

    /// See `Data.index(before:)`
    public func index(before i: Data.Index) -> Data.Index {
        return self.data.index(before: i)
    }

    /// See `Data.index(after:)`
    public func index(after i: Data.Index) -> Data.Index {
        return self.data.index(after: i)
    }

    /// See `Data.indices`
    public var indices: Range<Int> { 
        return self.data.indices
     }

    /// See `Data.makeIterator()`
    public func makeIterator() -> Data.Iterator {
        return self.data.makeIterator()
    }

    /// See `Data.range(of:options:in:)`
    public func range(of dataToFind: Data, options: Data.SearchOptions = [], in range: Range<Data.Index>? = nil) -> Range<Data.Index>? {
        return self.data.range(of: dataToFind, options: options, in: range)
    }   

    /// See `Data.==`
    public static func == (d1: SentryDataWrapper, d2: SentryDataWrapper) -> Bool {
        return d1.data == d2.data
    }

    /// See `Data.hashValue`
    public var hashValue: Int { 
        return self.data.hashValue
    }

    /// See `Data.init?(base64Encoded:options:)`
    public init?(base64Encoded base64String: String, options: Data.Base64DecodingOptions = []) {
        guard let data = Data(base64Encoded: base64String, options: options) else {
            return nil
        }
        self.data = data
    }

    /// See `Data.init?(base64Encoded:options:)`
    public init?(base64Encoded base64Data: Data, options: Data.Base64DecodingOptions = []) {
        guard let data = Data(base64Encoded: base64Data, options: options) else {
            return nil
        }
        self.data = data
    }

    /// See `Data.base64EncodedString(options:)`
    public func base64EncodedString(options: Data.Base64EncodingOptions = []) -> String {
        return self.data.base64EncodedString(options: options)
    }

    /// See `Data.base64EncodedData(options:)`
    public func base64EncodedData(options: Data.Base64EncodingOptions = []) -> Data {
        return self.data.base64EncodedData(options: options)
    }

    /// See `Data.init(referencing:)`
    public init(referencing reference: NSData) {
        self.data = Data(referencing: reference)
    }
}

@available(iOS 18, macOS 15, tvOS 18, *)
extension SentryDataWrapper: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {

    /// See `Data.description`
    public var description: String {
        self.data.description
    }

    /// See `Data.debugDescription`
    public var debugDescription: String {
        self.data.debugDescription
    }

    /// See `Data.customMirror`
    public var customMirror: Mirror {
        self.data.customMirror
    }
}

@available(iOS 18, macOS 15, tvOS 18, *)
extension SentryDataWrapper: Codable {

    /// See `Data.init(from:)`
    public init(from decoder: any Decoder) throws {
        self.data = try Data(from: decoder)
    }

    /// See `Data.encode(to:)`
    public func encode(to encoder: any Encoder) throws {
        try self.data.encode(to: encoder)
    }
}
