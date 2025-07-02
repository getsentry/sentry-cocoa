import Foundation

@objc protocol SentryLogBatcherDelegate {
    func send(_ envelope: SentryEnvelope)
}

@objc class SentryLogBatcher: NSObject {
    private let delegate: SentryLogBatcherDelegate
    
    @objc
    init(delegate: SentryLogBatcherDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    @objc
    func processLog(_ log: SentryLog, with scope: Scope) {
        do {
            let envelope = try SentryEnvelope(logs: [log])
            delegate.send(envelope)
        } catch {
            SentrySDKLog.error("Failed to create logs envelope.")
        }
    }
}
