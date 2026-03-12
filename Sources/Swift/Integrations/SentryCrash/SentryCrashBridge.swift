@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

/// Facade that bridges the Sentry SDK layer to the SentryCrash subsystem.
///
/// `SentryCrashBridge` is the single entry point through which SentryCrash
/// accesses SDK services. It replaces direct `SentryDependencyContainer`
/// look-ups inside the crash reporter, keeping the dependency direction
/// one-way: **Sentry → SentryCrash**, never the reverse.
///
/// ## Isolation boundary
///
/// This bridge is the first step toward fully isolating SentryCrash from the
/// SDK. Today the two layers still share a handful of model types (e.g.
/// `SentryCrashSwift`, notification-center wrappers). Future work will replace
/// those shared types with protocol abstractions so that SentryCrash can be
/// built and tested independently.
///
/// ## Exposed services
///
/// | Service                        | Used by SentryCrash for                                 |
/// |--------------------------------|---------------------------------------------------------|
/// | `notificationCenterWrapper`    | Observing app-lifecycle events (foreground, background)  |
/// | `dateProvider`                 | Timestamping crash reports and session boundaries        |
/// | `crashReporter`                | Reading system info, crash state, and launch metadata    |
/// | `uncaughtExceptionHandler`     | Installing / reading the NSException handler             |
/// | `activeScreenSize()` (UIKit)   | Recording screen dimensions in device context            |
///
/// ## Threading
///
/// The bridge is created once during `SentryCrashIntegration.install(with:)` and
/// is safe to read from any thread after initialization. The
/// `uncaughtExceptionHandler` property may be written from the SentryCrash
/// installation path and read from the crash-time exception handler.
///
/// ## Usage
///
/// The bridge is created by the integration layer and passed down:
///
/// ```swift
/// let bridge = SentryCrashBridge(
///     notificationCenterWrapper: notificationCenter,
///     dateProvider: dateProvider,
///     crashReporter: crashReporter
/// )
/// // Passed to SentryCrashWrapper, SentryCrashIntegrationSessionHandler,
/// // and the underlying SentryCrash / SentryCrashInstallation instances.
/// ```
@objc @_spi(Private) public final class SentryCrashBridge: NSObject {

    // MARK: - Service Properties

    /// Wrapper around `NSNotificationCenter` used by SentryCrash to observe
    /// app-lifecycle transitions (e.g. `UIApplicationDidBecomeActiveNotification`).
    @objc public let notificationCenterWrapper: SentryNSNotificationCenterWrapper

    /// Provides the current date/time. Used for timestamping crash reports and
    /// computing session durations.
    @objc public let dateProvider: SentryCurrentDateProvider

    /// The crash reporter instance that owns system info, crash state, and the
    /// on-disk report store. This is the main object SentryCrash interacts with.
    @objc public let crashReporter: SentryCrashSwift

    /// The C-convention uncaught-exception handler installed by SentryCrash.
    ///
    /// This is a convenience proxy for `crashReporter.uncaughtExceptionHandler`.
    /// The NSException monitor (`SentryCrashMonitor_NSException`) writes this
    /// during installation so it can be restored if monitoring is later disabled.
    @objc public var uncaughtExceptionHandler: (@convention(c) (NSException) -> Void)? {
        get { crashReporter.uncaughtExceptionHandler }
        set { crashReporter.uncaughtExceptionHandler = newValue }
    }

    // MARK: - Platform-Specific Services

    #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    /// Returns the size of the active screen in points (iOS/tvOS only).
    ///
    /// Delegates to `SentryDependencyContainerSwiftHelper` which reads the key
    /// window's scene. Returns `CGSize.zero` when no active scene is available.
    @objc public func activeScreenSize() -> CGSize {
        return SentryDependencyContainerSwiftHelper.activeScreenSize()
    }
    #endif

    // MARK: - Initialization

    /// Creates a bridge with the SDK services that SentryCrash requires.
    ///
    /// - Parameters:
    ///   - notificationCenterWrapper: Wrapper for subscribing to app-lifecycle
    ///     notifications.
    ///   - dateProvider: Provider for current timestamps.
    ///   - crashReporter: The crash reporter that manages on-disk reports and
    ///     system info.
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
