// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

/**
 * Concrete facade bridging SDK services to SentryCrash without requiring direct
 * SentryDependencyContainer access.
 *
 * This class provides a single point of access for SentryCrash to SDK services,
 * decoupling the crash reporting subsystem from the SDK's dependency container.
 * It exposes only the five services SentryCrash needs: notification center wrapper,
 * date provider, crash reporter, uncaught exception handler, and active screen size.
 *
 * The bridge follows the facade pattern established in the codebase, similar to
 * SentryDependencyContainerSwiftHelper, providing a clean architectural boundary
 * between layers.
 */
@objc @_spi(Private) public final class SentryCrashBridge: NSObject {

    // MARK: - Service Properties

    /// Notification center wrapper for app lifecycle events
    @objc public let notificationCenterWrapper: SentryNSNotificationCenterWrapper

    /// Date provider for timestamps and system time
    @objc public let dateProvider: SentryCurrentDateProvider

    /// Crash reporter for system info and crash state
    @objc public let crashReporter: SentryCrashSwift

    /// Uncaught exception handler (bridges to crashReporter's property)
    @objc public var uncaughtExceptionHandler: (@convention(c) (NSException) -> Void)? {
        get { crashReporter.uncaughtExceptionHandler }
        set { crashReporter.uncaughtExceptionHandler = newValue }
    }

    // MARK: - Platform-Specific Services

    #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    /// Returns the active screen dimensions (iOS/tvOS only)
    @objc public func activeScreenSize() -> CGSize {
        return SentryDependencyContainerSwiftHelper.activeScreenSize()
    }
    #endif

    // MARK: - Initialization

    /// Initializes the bridge with required SDK services
    /// - Parameters:
    ///   - notificationCenterWrapper: Wrapper for notification center operations
    ///   - dateProvider: Provider for current date and time operations
    ///   - crashReporter: Crash reporting service
    @objc public init(
        notificationCenterWrapper: SentryNSNotificationCenterWrapper,
        dateProvider: SentryCurrentDateProvider,
        crashReporter: SentryCrashSwift
    ) {
        self.notificationCenterWrapper = notificationCenterWrapper
        self.dateProvider = dateProvider
        self.crashReporter = crashReporter
        super.init()
    }
}
// swiftlint:enable missing_docs
