@_implementationOnly import _SentryPrivate
import Foundation

@objc
@objcMembers
@_spi(Private) public class SentryLogBatcher: NSObject {
    
    private let client: SentryClient?
    
    @_spi(Private) public init(client: SentryClient?) {
        self.client = client
        super.init()
    }
    
    func add(_ log: SentryLog) {
        dispatch(logs: [log])
    }
    
    private func dispatch(logs: [SentryLog]) {
        guard let client, client.options.experimental.enableLogs else {
            return
        }
        do {
            let payload = ["items": logs]
            let data = try encodeToJSONData(data: payload)
            
            client.captureLogsData(data)
        } catch {
            SentrySDKLog.error("Failed to create logs envelope.")
        }
    }
}
