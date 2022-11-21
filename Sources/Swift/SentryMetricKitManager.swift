import Foundation
import MetricKit

@available(iOS 14.0, macCatalyst 14.0, macOS 12.0, *)
@objc public class SentryMetricKitManager: NSObject, MXMetricManagerSubscriber {
    
    @objc public func receiveReports() {
        let shared = MXMetricManager.shared
        shared.add(self)
    }
    
    @objc public func pauseReports() {
        let shared = MXMetricManager.shared
        shared.remove(self)
    }
    
    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            payload.diskWriteExceptionDiagnostics?.forEach {
                let json = $0.callStackTree.jsonRepresentation()
                _ = try! CallStackTree.from(data: json)
            }
        }
    }
}
