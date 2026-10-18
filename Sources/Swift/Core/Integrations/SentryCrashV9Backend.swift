#if !SDK_V10
// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

#if SWIFT_PACKAGE
@_silgen_name("sentrycrash_v9_registerSwiftBackend")
private func sentrycrash_v9_registerSwiftBackend()
#endif

/// Connects the V9-only Swift adapter module to the reporter-neutral SDK module.
///
/// SwiftPM compiles the adapter as a separate target so V10 never schedules its sources. The
/// registration function is a C symbol because a Swift module dependency in the opposite direction
/// would introduce a target cycle.
@_spi(Private) public enum SentryCrashV9Backend {
    public typealias IntegrationInstaller = (Options, SentryDependencyContainer) -> SentryIntegrationProtocol?
    public typealias CrashWrapperProvider = (SentryDependencyContainer) -> SentryCrashReporter
    public typealias ExceptionCapture = (SentryDependencyContainer, NSException) -> Void

    private static let lock = NSRecursiveLock()
    private static var integrationInstaller: IntegrationInstaller?
    private static var crashWrapperProvider: CrashWrapperProvider?
    private static var exceptionCapture: ExceptionCapture?

    #if !os(watchOS)
    public static func isSigtermReportingEnabled(in options: Options) -> Bool {
        options._enableSigtermReporting
    }
    #endif

    public static func finalizePreviousRunSession(
        options: Options,
        crashedLastLaunch: Bool,
        activeDurationSinceLastCrash: TimeInterval,
        dependencies: SentryDependencyContainer
    ) {
        dependencies.getPreviousRunSessionFinalizer(
            options: options,
            crashedLastLaunch: crashedLastLaunch,
            activeDurationSinceLastCrash: activeDurationSinceLastCrash
        )?.finalizeIfNeeded()
    }

    public static func register(
        integrationInstaller: @escaping IntegrationInstaller,
        crashWrapperProvider: @escaping CrashWrapperProvider,
        exceptionCapture: @escaping ExceptionCapture
    ) {
        lock.synchronized {
            self.integrationInstaller = integrationInstaller
            self.crashWrapperProvider = crashWrapperProvider
            self.exceptionCapture = exceptionCapture
        }
    }

    static func installIntegration(
        options: Options,
        dependencies: SentryDependencyContainer
    ) -> SentryIntegrationProtocol? {
        ensureRegistered()
        return integrationInstaller?(options, dependencies)
    }

    static func crashWrapper(for dependencies: SentryDependencyContainer) -> SentryCrashReporter {
        ensureRegistered()
        guard let crashWrapperProvider else {
            fatalError("The SentryCrash V9 Swift backend did not register a crash-wrapper provider.")
        }
        return crashWrapperProvider(dependencies)
    }

    static func capture(exception: NSException, dependencies: SentryDependencyContainer) {
        ensureRegistered()
        exceptionCapture?(dependencies, exception)
    }

    private static func ensureRegistered() {
        lock.synchronized {
            guard integrationInstaller == nil else { return }
            sentrycrash_v9_registerSwiftBackend()
        }
    }
}
// swiftlint:enable missing_docs
#endif // !SDK_V10
