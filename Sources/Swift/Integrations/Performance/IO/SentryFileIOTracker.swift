@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public protocol SpanProtocol {
    @objc(setDataValue:forKey:) func setData(value: Any, key: String)
    func finish()
    @objc(finishWithStatus:) func finish(status: SentrySpanStatus)
}

@_spi(Private) @objc public class SentryFileIOTracker: NSObject {

    private let helper: SentryFileIOTrackerHelper
    
    static func sharedInstance() -> SentryFileIOTracker? {
        // It is necessary to check if the SDK is enabled because accessing the tracker will otherwise
        // initialize the depency container without any configured SDK options. This is a known issue
        // and needs to be fixed in general.
        guard SentrySDK.isEnabled else {
            return nil
        }
        return Dependencies.fileIOTracker
    }

    @objc public init(threadInspector: SentryThreadInspector, processInfoWrapper: SentryProcessInfoSource) {
        helper = SentryFileIOTrackerHelper(threadInspector: threadInspector, processInfoWrapper: processInfoWrapper)
    }

    @objc public func enable() {
        helper.enable()
    }

    @objc public func disable() {
        helper.disable()
    }
    
    @discardableResult @objc(measureNSData:writeToFile:atomically:origin:method:) public func measure(_ data: Data, writeToFile path: String, atomically: Bool, origin: String, method: @escaping (String, Bool) -> Bool) -> Bool {
        helper.measure(data, writeToFile: path, atomically: atomically, origin: origin, method: method)
    }
    
    @objc(measureNSData:writeToFile:options:origin:error:method:) public func measure(_ data: Data, writeToFile path: String, options writeOptionsMask: NSData.WritingOptions, origin: String, method: @escaping (String, NSData.WritingOptions, NSErrorPointer) -> Bool) throws {
        try helper.measure(data, writeToFile: path, options: writeOptionsMask, origin: origin, method: method)
    }
    
    @objc(measureNSDataFromFile:origin:method:) public func measureNSData(fromFile path: String, origin: String, method: @escaping (String) -> Data?) -> Data? {
        helper.measureNSData(fromFile: path, origin: origin, method: method)
    }

    @objc(measureNSDataFromFile:options:origin:error:method:) public func measureNSData(fromFile path: String, options readOptionsMask: NSData.ReadingOptions, origin: String, method: @escaping (String, Data.ReadingOptions, NSErrorPointer) -> Data?) throws -> Data {
        try helper.measureNSData(fromFile: path, options: readOptionsMask, origin: origin, method: method)
    }

    @objc(measureNSDataFromURL:options:origin:error:method:) public func measureNSData(from url: URL, options readOptionsMask: NSData.ReadingOptions, origin: String, method: @escaping (URL, NSData.ReadingOptions, NSErrorPointer) -> Data?) throws -> Data {
        try helper.measureNSData(from: url, options: readOptionsMask, origin: origin, method: method)
    }
    
    @discardableResult @objc public func measureNSFileManagerCreateFile(atPath path: String, data: Data, attributes: [FileAttributeKey: Any], origin: String, method: @escaping (String, Data, [FileAttributeKey: Any]) -> Bool) -> Bool {
        helper.measureNSFileManagerCreateFile(atPath: path, data: data, attributes: attributes, origin: origin, method: method)
    }

    func span(forPath path: String, origin: String, operation: String) -> (any Span)? {
        helper.span(forPath: path, origin: origin, operation: operation)
    }

    func span(forPath path: String, origin: String, operation: String, size: UInt) -> (any Span)? {
        helper.span(forPath: path, origin: origin, operation: operation, size: size)
    }
}
