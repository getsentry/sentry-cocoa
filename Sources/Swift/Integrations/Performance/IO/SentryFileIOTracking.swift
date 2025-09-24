@_spi(Private) @objc public protocol SentryFileIOTracking {
    func enable()
    func disable()
    
    func measureNSData(_ data: Data, writeToFile path: String, atomically: Bool, origin: String, method: (String, Bool) -> Bool) -> Bool
    
    func measureNSData(_ data: Data, writeToFile path: String, options writeOptionsMask: NSData.WritingOptions, origin: String, method: (String, NSData.WritingOptions, NSErrorPointer) -> Bool) throws
    
    func measureNSData(fromFile path: String, origin: String, method: (String) -> Data?) -> Data?

    func measureNSData(fromFile path: String, options readOptionsMask: NSData.ReadingOptions, origin: String, method: (String, Data.ReadingOptions, NSErrorPointer) -> Data?) throws -> Data

    func measureNSData(fromURL url: URL, options readOptionsMask: NSData.ReadingOptions, origin: String, method: (URL, NSData.ReadingOptions, NSErrorPointer) -> Data?) throws -> Data
    
    func measureNSFileManagerCreateFileAtPath(_ path: String, data: Data, attributes: [FileAttributeKey: Any], origin: String, method: (String, NSData, [FileAttributeKey: Any]) -> Bool) -> Bool
    
    func span(forPath path: String, origin: String, operation: String) -> (any Span)?

    func span(forPath path: String, origin: String, operation: String, size: UInt) -> (any Span)?
}
