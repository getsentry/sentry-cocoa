#if !SDK_V10
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import ContactProvider
import ExtensionFoundation
import Foundation
import SentrySampleShared
#if !SDK_V10
import SentrySwift
#else
import Sentry
#endif

/// A Contact Provider extension, which is an ExtensionKit extension: it declares its extension point as
/// `EXAppExtensionAttributes` › `EXExtensionPointIdentifier` and has no `NSExtension` dictionary.
///
/// The extension has no UI, so it reports the state of the SDK as contacts that show up in the Contacts app
/// after enabling the provider in the iOS-Swift app.
@main
final class ContactProviderExtension: ContactProvider.ContactProviderExtension {
    private let rootContainerEnumerator: ContactProviderRootContainerEnumerator

    required init() {
        Self.setupSentry()
        rootContainerEnumerator = ContactProviderRootContainerEnumerator()
    }

    func configure(for domain: ContactProviderDomain) {
        SentrySDK.capture(message: "iOS-Swift-ContactProviderExtension: configure called")
    }

    func enumerator(for collection: ContactItem.Identifier) -> ContactItemEnumerator {
        return rootContainerEnumerator
    }

    func invalidate() async throws {
        // Nothing to clean up
    }

    private static func setupSentry() {
        guard !SentrySDK.isEnabled else { return }

        // For this extension we need a specific configuration set, therefore we do not use the shared sample initializer
        SentrySDK.start { options in
            options.dsn = SentrySDKWrapper.defaultDSN
            options.debug = true
            SentrySDKWrapper.shared.configureDataCollection(options)

            #if !SDK_V10
            // App Hang Tracking must be enabled, but should not be installed
            options.enableAppHangTracking = true
            #endif // !SDK_V10
        }
    }

    static var isANRInstalled: Bool {
        isSentryEnabled && SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().contains("ANRTracking")
    }

    static var isWatchdogInstalled: Bool {
        isSentryEnabled && SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames().contains("WatchdogTerminationTracking")
    }

    static var isSentryEnabled: Bool {
        SentrySDK.isEnabled
    }
}
