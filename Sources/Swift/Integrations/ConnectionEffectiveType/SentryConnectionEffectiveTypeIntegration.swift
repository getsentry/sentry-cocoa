#if os(iOS) && !targetEnvironment(macCatalyst)

internal import _SentryPrivate
import Foundation

/// Reports the generation of the cellular network technology as `connection_effective_type` in
/// the device context, while `options.experimental.enableConnectionEffectiveType` is enabled.
final class SentryConnectionEffectiveTypeIntegration<Dependencies: ReachabilityProvider>: NSObject, SwiftIntegration {

    private let reachability: SentryReachability
    private let provider: SentryCellularNetworkTechnologyProviding

    /// Starting and stopping go through one serial queue, so a stop that follows a start always
    /// runs after it.
    private let dispatchQueue: SentryDispatchQueueWrapper

    convenience init?(with options: Options, dependencies: Dependencies) {
        self.init(
            options: options,
            reachability: dependencies.reachability,
            provider: SentryCellularNetworkTechnologyProvider(),
            dispatchQueue: SentryDispatchQueueWrapper(name: "io.sentry.cocoa.connection-effective-type")
        )
    }

    init?(
        options: Options,
        reachability: SentryReachability,
        provider: SentryCellularNetworkTechnologyProviding,
        dispatchQueue: SentryDispatchQueueWrapper
    ) {
        guard options.experimental.enableConnectionEffectiveType else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableConnectionEffectiveType is disabled.")
            return nil
        }
        self.reachability = reachability
        self.provider = provider
        self.dispatchQueue = dispatchQueue
        super.init()

        // Starting the provider talks to a system service, and the SDK usually starts on the main
        // thread.
        dispatchQueue.dispatchAsync {
            provider.startMonitoring()
        }
        reachability.setCellularNetworkTechnologyProvider(provider)
    }

    func uninstall() {
        reachability.setCellularNetworkTechnologyProvider(nil)
        let provider = self.provider
        dispatchQueue.dispatchAsync {
            provider.stopMonitoring()
        }
    }

    static var name: String {
        "SentryConnectionEffectiveTypeIntegration"
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
