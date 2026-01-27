protocol TelemetryBufferConfig<Item> {
    associatedtype Item

    var sendDefaultPii: Bool { get }

    var flushTimeout: TimeInterval { get }
    var maxItemCount: Int { get }
    var maxBufferSizeBytes: Int { get }

    var beforeSendItem: ((Item) -> Item?)? { get }

    var capturedDataCallback: (_ data: Data, _ count: Int) -> Void { get }
}
