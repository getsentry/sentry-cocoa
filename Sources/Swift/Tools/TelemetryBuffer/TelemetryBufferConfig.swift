protocol TelemetryBufferConfig<Item> {
    associatedtype Item

    var flushTimeout: TimeInterval { get }
    var maxItemCount: Int { get }
    var maxBufferSizeBytes: Int { get }
    
    var capturedDataCallback: (_ data: Data, _ count: Int) -> Void { get }
}
