import Foundation
import MetricKit
import Sentry

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

}
