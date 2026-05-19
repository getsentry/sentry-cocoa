// swiftlint:disable missing_docs
import Foundation

#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

// See SentryReplayOptionsCompat.swift for the rationale on why this
// wrapper exists (mangled ObjC runtime names).
//
// This wrapper avoids type-erasing because SentryExperimentalOptions'
// public interface uses only Bool properties.  No SDK types leak into
// public signatures.
@objc(SentryExperimentalOptions)
public class SentryExperimentalOptionsCompat: NSObject {
    @objc public var enableUnhandledCPPExceptionsV2: Bool = false
    @objc public var enableWatchdogTerminationsV2: Bool = false
    @objc public var enableReplayNetworkDetailsCapturing: Bool = false
}
