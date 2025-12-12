protocol BatcherConfig<Item> {
    associatedtype Item

    var flushTimeout: TimeInterval { get }
    var maxItemCount: Int { get }
    var maxBufferSizeBytes: Int { get }

    var beforeSendItem: ((Item) -> Item?)? { get }
    var installationId: String? { get }

    var capturedDataCallback: (_ data: Data, _ count: Int) -> Void { get }
}
