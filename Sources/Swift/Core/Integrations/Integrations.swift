@_implementationOnly import _SentryPrivate

// The Swift counterpart to `SentryObjcIntegrationProtocol`. This protocol allows
// injecting the dependencies in a way that does not require the Integration to
// depend on SentryDependencyContainer.
protocol SwiftIntegration: SentryIntegrationProtocol {
    // The dependencies required for the integration. The easiest way to satisfy this requirement when migrating from ObjC
    // is to define it as `SentryDependencyContainer` with a typealias. However, a generic Swift class that has a protocol
    // constraint on the `Dependencies` type can make it easier to test and to use without a direct dependency on all
    // of `SentryDependencyContainer`.
    associatedtype Dependencies
    
    // The initializer is failable, return nil if the integration was not installed, for example when the options that enable the integration is not enabled.
    init?(with options: Options, dependencies: Dependencies)
    
    // Name of the integration that is used by `SentrySdkInfo`
    static var name: String { get }
}

// Type erases the `Integration` so that it can be stored in an array and used for `addInstalledIntegration`
private struct AnyIntegration {
    let install: (Options, SentryDependencyContainer) -> SentryIntegrationProtocol?
    let name: String

    init<I: SwiftIntegration>(_ integration: I.Type) where I.Dependencies == SentryDependencyContainer {
        name = I.name
        install = {
            integration.init(with: $0, dependencies: $1)
        }
    }
}

// Bridges to ObjC code to trigger installing the integrations
@_spi(Private) @objc public final class SentrySwiftIntegrationInstaller: NSObject {
    @objc public class func install(with options: Options) {
        let dependencies = SentryDependencyContainer.sharedInstance()

        var integrations: [AnyIntegration] = [
            .init(SwiftAsyncIntegration.self),
            .init(SentryAutoSessionTrackingIntegration.self)
        ]
        
        #if os(iOS) && !SENTRY_NO_UIKIT
        integrations.append(.init(UserFeedbackIntegration.self))
        #endif
        
        #if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)
        integrations.append(.init(FlushLogsIntegration.self))
        #endif

        #if (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT
        integrations.append(.init(SentryScreenshotIntegration.self))
        #endif

        #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
        integrations.append(.init(SentrySessionReplayIntegrationObjC.self))
        #endif
        
        #if os(iOS) || os(macOS)
        if #available(macOS 12.0, *) {
            integrations.append(.init(SentryMetricKitIntegration.self))
        }
        #endif
        
        integrations.forEach { anyIntegration in
            guard let integration = anyIntegration.install(options, dependencies) else { return }

            SentrySDKInternal.currentHub().addInstalledIntegration(integration, name: anyIntegration.name)
        }
    }
}
