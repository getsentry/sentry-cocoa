import Foundation

@objc
@objcMembers
public final class SentryLogger: NSObject {
    private let hub: SentryHub
    private let dateProvider: SentryCurrentDateProvider
    private let batcher: SentryLogBatcher
    
    @_spi(Private) public init(hub: SentryHub, dateProvider: SentryCurrentDateProvider, batcher: SentryLogBatcher) {
        self.hub = hub
        self.dateProvider = dateProvider
        self.batcher = batcher
        super.init()
    }
    
    public func trace(_ body: String) {
        captureLog(level: .trace, body: body, attributes: [:])
    }
    
    public func trace(_ body: String, attributes: [String: Any]) {
        captureLog(level: .trace, body: body, attributes: attributes)
    }
    
    public func debug(_ body: String) {
        captureLog(level: .debug, body: body, attributes: [:])
    }
    
    public func debug(_ body: String, attributes: [String: Any]) {
        captureLog(level: .debug, body: body, attributes: attributes)
    }
    
    public func info(_ body: String) {
        captureLog(level: .info, body: body, attributes: [:])
    }
    
    public func info(_ body: String, attributes: [String: Any]) {
        captureLog(level: .info, body: body, attributes: attributes)
    }
    
    public func warn(_ body: String) {
        captureLog(level: .warn, body: body, attributes: [:])
    }
    
    public func warn(_ body: String, attributes: [String: Any]) {
        captureLog(level: .warn, body: body, attributes: attributes)
    }
    
    public func error(_ body: String) {
        captureLog(level: .error, body: body, attributes: [:])
    }
    
    public func error(_ body: String, attributes: [String: Any]) {
        captureLog(level: .error, body: body, attributes: attributes)
    }
    
    public func fatal(_ body: String) {
        captureLog(level: .fatal, body: body, attributes: [:])
    }
    
    public func fatal(_ body: String, attributes: [String: Any]) {
        captureLog(level: .fatal, body: body, attributes: attributes)
    }
    
    // MARK: - Private
    
    private func captureLog(level: SentryLog.Level, body: String, attributes: [String: Any]) {
        let logAttributes = attributes.mapValues { SentryLog.Attribute(value: $0) }
        let log = SentryLog(
            timestamp: dateProvider.date(),
            level: level,
            body: body,
            attributes: logAttributes
        )
        batcher.add(log)
    }
}
