protocol BatchStorage<Element> {
    associatedtype Element

    mutating func append(_ element: Element) throws
    mutating func flush()

    var data: Data { get }
    var count: Int { get }
    var size: Int { get }
}
