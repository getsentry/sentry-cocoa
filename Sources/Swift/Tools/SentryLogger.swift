import Foundation

@objc
public final class SentryLogger: NSObject {
    let hub: SentryHub
    let dateProvider: SentryCurrentDateProvider
    
    @objc
    init(hub: SentryHub, dateProvider: SentryCurrentDateProvider) {
        self.hub = hub
        self.dateProvider = dateProvider
        super.init()
    }
    
    @objc
    public func trace(_ body: String) {
        captureLog(level: .trace, body: body, attributes: [:])
    }
    
    @objc
    public func trace(_ body: String, attributes: [String: Any]) {
        captureLog(level: .trace, body: body, attributes: attributes)
    }
    
    @objc
    public func debug(_ body: String) {
        captureLog(level: .debug, body: body, attributes: [:])
    }
    
    @objc
    public func debug(_ body: String, attributes: [String: Any]) {
        captureLog(level: .debug, body: body, attributes: attributes)
    }
    
    @objc
    public func info(_ body: String) {
        captureLog(level: .info, body: body, attributes: [:])
    }
    
    @objc
    public func info(_ body: String, attributes: [String: Any]) {
        captureLog(level: .info, body: body, attributes: attributes)
    }
    
    @objc
    public func warn(_ body: String) {
        captureLog(level: .warn, body: body, attributes: [:])
    }
    
    @objc
    public func warn(_ body: String, attributes: [String: Any]) {
        captureLog(level: .warn, body: body, attributes: attributes)
    }
    
    @objc
    public func error(_ body: String) {
        captureLog(level: .error, body: body, attributes: [:])
    }
    
    @objc
    public func error(_ body: String, attributes: [String: Any]) {
        captureLog(level: .error, body: body, attributes: attributes)
    }
    
    @objc
    public func fatal(_ body: String) {
        captureLog(level: .fatal, body: body, attributes: [:])
    }
    
    @objc
    public func fatal(_ body: String, attributes: [String: Any]) {
        captureLog(level: .fatal, body: body, attributes: attributes)
    }
    
    // MARK: - Private
    
    private func captureLog(level: SentryLog.Level, body: String, attributes: [String: Any]) {
        let convertedAttributes = attributes.mapValues { SentryLog.Attribute(value: $0) }
        
        hub.capture(
            log: SentryLog(
                timestamp: dateProvider.date(),
                level: level,
                body: body,
                attributes: convertedAttributes
            )
        )
    }
}
