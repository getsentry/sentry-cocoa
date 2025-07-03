import Foundation

@objc
@_spi(Private) public protocol SentryLogBatcherDelegate {
    func send(_ envelope: SentryEnvelope)
}

@objc
@objcMembers
@_spi(Private) public class SentryLogBatcher: NSObject {
    private weak var delegate: (SentryLogBatcherDelegate)?
    
    public init(delegate: SentryLogBatcherDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    public func processLog(_ log: SentryLog, with scope: Scope) {
        do {
            let envelope = try SentryEnvelope(logs: [log])
            delegate?.send(envelope)
        } catch {
            SentrySDKLog.error("Failed to create logs envelope.")
        }
    }
}
