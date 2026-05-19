// swiftlint:disable missing_docs
import Foundation
import SentryObjCTypes

#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

// TYPE-ERASING: see SentryObjCCompat.swift for the full rationale.
// Parameters like `options: NSObject` and `replayOptions: NSObject` are
// type-erased because internal import prevents Options and
// SentryReplayOptions from appearing in public signatures.
extension SentryObjCBridge {

    @objc public static func bridgeBeforeSendMetric(
        forOptions options: NSObject,
        callback: @escaping (SentryObjCMetric) -> SentryObjCMetric?
    ) {
        guard let opts = options as? Options else { return }
        opts.beforeSendMetric = { metric in
            guard let result = callback(metric.toObjC()) else { return nil }
            return result.toSwift()
        }
    }

    #if canImport(UIKit) && !os(visionOS)
    @objc public static func bridgeReplayNetworkDetailAllowUrls(
        forReplayOptions replayOptions: NSObject,
        urls: [Any]
    ) {
        guard let opts = replayOptions as? SentryReplayOptions else { return }
        opts.networkDetailAllowUrls = urls.compactMap { $0 as? SentryUrlMatchable }
    }

    @objc public static func bridgeReplayNetworkDetailDenyUrls(
        forReplayOptions replayOptions: NSObject,
        urls: [Any]
    ) {
        guard let opts = replayOptions as? SentryReplayOptions else { return }
        opts.networkDetailDenyUrls = urls.compactMap { $0 as? SentryUrlMatchable }
    }
    #endif
}
