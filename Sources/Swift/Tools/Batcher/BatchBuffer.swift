enum BatchBufferError: Error {
    case bufferFull
}

protocol BatchBuffer<Item> {
    associatedtype Item

    /// Adds the given item to the storage
    ///
    /// - Throws: Can throw errors due to e.g. encoding errors
    mutating func append(_ item: Item) throws

    /// Clears all items from the storage
    mutating func clear()

    /// Number of elements in the storage
    var itemsCount: Int { get }

    /// Sum of the size of encoded items in the storage
    var itemsDataSize: Int { get }

    /// Returns the data collected in this storage in batched format
    var batchedData: Data { get }
}
