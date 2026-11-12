import Foundation
#if !SDK_V10
import SentrySwift
#else
import Sentry
#endif
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

    @IBAction func triggerFatalHangDiagnostic(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Trigger Fatal Hang?",
            message: "This freezes the app indefinitely. Use a physical device without a debugger. Background the app and wait. If iOS does not terminate it, close it manually, then relaunch. MetricKit reports may be delayed or absent.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Freeze App", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.highlightButton(sender)
            self.hangStressor.startFatalHang()
        })
        present(alert, animated: true)
    }
}
