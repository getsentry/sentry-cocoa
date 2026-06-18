// Only gated for these platforms so we can use Combine
#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
@_implementationOnly import _SentryPrivate
import Combine

protocol SentryHangTrackingV3IntegrationProtocol {}

typealias SentryHangTrackingV3IntegrationDependencies = HangTrackerProvider & AppHangDependencies & ClientProvider

final class SentryHangTrackingV3Integration<Dependencies: SentryHangTrackingV3IntegrationDependencies>: NSObject, SwiftIntegration, SentryHangTrackingV3IntegrationProtocol {

    private let hangDetection: AppHangDetection
    private let observer: AnyCancellable

    init?(with options: Options, dependencies: Dependencies) {
        guard options.experimental.appHangs.enableV3 else {
            return nil
        }

        hangDetection = DefaultAppHangDetection(
            dependencies: dependencies,
            options: DefaultAppHangDetectionOptions(
                appHangThreshold: options.experimental.appHangs.appHangThreshold
            )
        )
        observer = hangDetection.onHangDetected.sink { [dependencies] duration in
            guard let client = dependencies.client else {
                SentrySDKLog.debug("SentryHangTrackingV3Integration: No client available, dropping metric")
                return
            }

            // Create an fatal error event based on the app hang duration
            let event = Event(level: .fatal)
            event.message = .init(formatted: "App hang detected")
            var eventContext = event.context ?? [:]
            let appHangContext: [String: Any] = [
                "duration": duration
            ]
            eventContext["app_hang"] = appHangContext
            event.context = eventContext

            client.capture(event: event)
        }

        super.init()
    }

    func uninstall() {}

    static var name: String {
        "SentryHangTrackingV3Integration"
    }
}
#endif
