extension Sequence {
    /// Returns an array of unique values
    ///
    /// - Parameter key: Closure used to return unique identifier for the given ``Element``
    func unique<T: Hashable>(by key: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert(key($0)).inserted }
    }
}
