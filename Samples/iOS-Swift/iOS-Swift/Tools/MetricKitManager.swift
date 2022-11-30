import Foundation
import MetricKit
import Sentry

@available(iOS 14.0, *)
class MetricKitManager: NSObject, MXMetricManagerSubscriber {
    func receiveReports() {
        let shared = MXMetricManager.shared
        shared.add(self)
    }
    
    func pauseReports() {
        let shared = MXMetricManager.shared
        shared.remove(self)
    }
    
    func didReceive(_ payloads: [MXMetricPayload]) {
        var attachments: [Attachment] = []
        for payload in payloads {
            let attachment = Attachment(data: payload.jsonRepresentation(), filename: "MXMetricPayload.json")
            attachments.append(attachment)
        }
        
        SentrySDK.capture(message: "MetricKit received MXMetricPayload.") { scope in
            attachments.forEach { scope.addAttachment($0) }
        }
    }
    
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        var attachments: [Attachment] = []
        for payload in payloads {
            let attachment = Attachment(data: payload.jsonRepresentation(), filename: "MXDiagnosticPayload.json")
            attachments.append(attachment)
        }
        
        SentrySDK.capture(message: "MetricKit received MXDiagnosticPayload.") { scope in
            attachments.forEach { scope.addAttachment($0) }
        }
    }
}
