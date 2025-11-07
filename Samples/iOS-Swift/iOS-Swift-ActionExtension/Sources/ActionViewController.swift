import Sentry
@_spi(Private) @testable import Sentry
import SentrySampleShared
import UIKit
import UniformTypeIdentifiers

class ActionViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup view first
        view.backgroundColor = .systemBackground
        
        // Setup Sentry SDK
        setupSentrySDK()
        
        // Display ANR status
        setupStatusLabel()
    }
    
    private func setupSentrySDK() {
        SentrySDKWrapper.shared.startSentry()
        
        // Small delay to ensure SDK is initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkANRStatus()
        }
    }
    
    private func checkANRStatus() {
        // Verify ANR tracking is disabled
        var anrInstalled = false
        if SentrySDK.isEnabled {
            let integrationNames = SentrySDKInternal.trimmedInstalledIntegrationNames()
            anrInstalled = integrationNames.contains("ANRTracking")
        }
        
        if anrInstalled {
            print("❌ ERROR: ANR tracking should be disabled in Action Extension but it's enabled!")
        } else {
            print("✅ ANR tracking is correctly disabled in Action Extension")
        }
        
        // Update label if view is still loaded
        if view.window != nil {
            updateStatusLabel(anrInstalled: anrInstalled)
        }
    }
    
    private func setupStatusLabel() {
        // Initial check - might show "checking..." if SDK not ready
        var anrInstalled = false
        if SentrySDK.isEnabled {
            let integrationNames = SentrySDKInternal.trimmedInstalledIntegrationNames()
            anrInstalled = integrationNames.contains("ANRTracking")
        }
        
        updateStatusLabel(anrInstalled: anrInstalled)
    }
    
    private func updateStatusLabel(anrInstalled: Bool) {
        // Remove existing label if any
        view.subviews.forEach { $0.removeFromSuperview() }
        
        let statusLabel = UILabel()
        statusLabel.text = anrInstalled ? "❌ ANR Enabled (ERROR!)" : "✅ ANR Disabled"
        statusLabel.textColor = anrInstalled ? .red : .green
        statusLabel.font = .systemFont(ofSize: 24, weight: .bold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    @IBAction func done() {
        SentrySDK.capture(message: "iOS-Swift-ActionExtension: done called")
        let returnItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        extensionContext?.completeRequest(returningItems: returnItems, completionHandler: nil)
    }
}
