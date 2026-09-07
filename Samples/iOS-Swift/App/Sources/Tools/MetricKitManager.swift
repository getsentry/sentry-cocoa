import Foundation
import MetricKit
import SentrySwift

class MetricKitManager: NSObject, MXMetricManagerSubscriber {
    private var manager: AnyObject?

    func receiveReports() {
        let shared = MXMetricManager.shared
        shared.add(self)

        if #available(iOS 27.0, *) {
            let manager = MetricKit.MetricManager()
            self.manager = manager as AnyObject
            Task {
                for await report in manager.metricReports {
                    print(report)
                }
            }
            Task {
                for await report in manager.diagnosticReports {
                    print(report)
                }
            }
        }
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
