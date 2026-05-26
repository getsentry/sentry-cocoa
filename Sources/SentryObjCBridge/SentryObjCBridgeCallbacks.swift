import Foundation
import SentryObjCTypes

#if SWIFT_PACKAGE
import SentrySwift
#else
import Sentry
#endif

extension SentrySwiftBridge {

    /// Bridges the ObjC `beforeSendMetric` block into the Swift SDK's typed closure.
    @objc public static func bridgeBeforeSendMetric(
        forOptions options: Options,
        callback: @escaping (SentryObjCMetric) -> SentryObjCMetric?
    ) {
        options.beforeSendMetric = { metric in
            guard let result = callback(metric.toObjC()) else { return nil }
            return result.toSwift()
        }
    }

    #if canImport(UIKit) && !os(visionOS)
    /// Bridges ObjC replay network-detail allow-URLs into the Swift replay options.
    @objc public static func bridgeReplayNetworkDetailAllowUrls(
        forReplayOptions replayOptions: SentryReplayOptions,
        urls: [Any]
    ) {
        replayOptions.networkDetailAllowUrls = urls.compactMap { $0 as? SentryUrlMatchable }
    }

    /// Bridges ObjC replay network-detail deny-URLs into the Swift replay options.
    @objc public static func bridgeReplayNetworkDetailDenyUrls(
        forReplayOptions replayOptions: SentryReplayOptions,
        urls: [Any]
    ) {
        replayOptions.networkDetailDenyUrls = urls.compactMap { $0 as? SentryUrlMatchable }
    }
    #endif
}
