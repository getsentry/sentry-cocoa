import Foundation
import SentrySwift
import UIKit

final class MetricKitViewController: UIViewController {
    private let diskWriteStressor = MetricKitDiskWriteStressor()
    private let cpuStressor = MetricKitCPUStressor()
    private let hangStressor = MetricKitHangStressor()
    private let catalogService = MetricKitSample.CatalogService()
    private let checkoutService = MetricKitSample.CheckoutService()

    @IBAction func triggerCrashDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        SentrySDK.logger.fatal(
            "MetricKit crash stressor started",
            attributes: ["stressor": "crash"]
        )
        SentrySDK.crash()
    }

    @IBAction func triggerDiskWriteExceptionDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        diskWriteStressor.start()
    }

    @IBAction func triggerCPUExceptionDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        cpuStressor.start()
    }

    @IBAction func triggerCatalogHangDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        hangStressor.start(workload: "catalog_refresh") {
            try catalogService.refreshCatalog()
        }
    }

    @IBAction func triggerCheckoutHangDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        hangStressor.start(workload: "checkout") {
            try checkoutService.checkout()
        }
    }
}
