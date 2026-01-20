// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public final class SentryFileIOTracker: NSObject {

    private let helper: SentryFileIOTrackerHelper
    private let processInfoWrapper: SentryProcessInfoSource
    
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
        self.processInfoWrapper = processInfoWrapper
        helper = SentryFileIOTrackerHelper {
            threadInspector.stacktraceForCurrentThreadAsyncUnsafe()
        }
    }

    @objc public func enable() {
        helper.enable()
    }

    @objc public func disable() {
        helper.disable()
    }
    
    @discardableResult @objc(measureNSData:writeToFile:atomically:origin:method:) public func measure(_ data: Data, writeToFile path: String, atomically: Bool, origin: String, method: @escaping (String, Bool) -> Bool) -> Bool {
        helper.measure(data, writeToFile: path, atomically: atomically, origin: origin, processDirectoryPath: processInfoWrapper.processDirectoryPath, method: method)
    }
    
    @objc(measureNSData:writeToFile:options:origin:error:method:) public func measure(_ data: Data, writeToFile path: String, options writeOptionsMask: NSData.WritingOptions, origin: String, method: @escaping (String, NSData.WritingOptions, NSErrorPointer) -> Bool) throws {
        try helper.measure(data, writeToFile: path, options: writeOptionsMask, origin: origin, processDirectoryPath: processInfoWrapper.processDirectoryPath, method: method)
    }
    
    // This must use NSData not Data because it is used to swizzle ObjC
    @objc(measureNSDataFromFile:origin:method:) public func measureNSData(fromFile path: String, origin: String, method: @escaping (String) -> NSData?) -> NSData? {
        var result: NSData?
        helper.measureNSData(fromFile: path, origin: origin, processDirectoryPath: processInfoWrapper.processDirectoryPath) {
            result = method(path)
            return NSNumber(value: result?.length ?? 0)
        }
        return result
    }

    // This must use NSData not Data because it is used to swizzle ObjC
    @objc(measureNSDataFromFile:options:origin:error:method:) public func measureNSData(fromFile path: String, options readOptionsMask: NSData.ReadingOptions, origin: String, error: NSErrorPointer, method: @escaping (String, Data.ReadingOptions, NSErrorPointer) -> NSData?) -> NSData? {
        var result: NSData?
        helper.measureNSData(fromFile: path, origin: origin, processDirectoryPath: processInfoWrapper.processDirectoryPath) {
            result = method(path, readOptionsMask, error)
            return NSNumber(value: result?.length ?? 0)
        }
        return result
    }

    // This must use NSData not Data because it is used to swizzle ObjC
    @objc(measureNSDataFromURL:options:origin:error:method:) public func measureNSData(from url: URL, options readOptionsMask: NSData.ReadingOptions, origin: String, error: NSErrorPointer, method: @escaping (URL, NSData.ReadingOptions, NSErrorPointer) -> NSData?) -> NSData? {
        var result: NSData?
        helper.measureNSData(from: url, origin: origin, processDirectoryPath: processInfoWrapper.processDirectoryPath) {
            result = method(url, readOptionsMask, error)
            return NSNumber(value: result?.length ?? 0)
        }
        return result
    }
    
    @discardableResult @objc public func measureNSFileManagerCreateFile(atPath path: String, data: Data, attributes: [FileAttributeKey: Any], origin: String, method: @escaping (String, Data, [FileAttributeKey: Any]) -> Bool) -> Bool {
        helper.measureNSFileManagerCreateFile(atPath: path, data: data, attributes: attributes, origin: origin, processDirectoryPath: processInfoWrapper.processDirectoryPath, method: method)
    }

    func span(forPath path: String, origin: String, operation: String) -> (any Span)? {
        helper.span(forPath: path, origin: origin, operation: operation, processDirectoryPath: processInfoWrapper.processDirectoryPath)
    }

    func span(forPath path: String, origin: String, operation: String, size: UInt) -> (any Span)? {
        helper.span(forPath: path, origin: origin, operation: operation, processDirectoryPath: processInfoWrapper.processDirectoryPath, size: size)
    }
}
// swiftlint:enable missing_docs
