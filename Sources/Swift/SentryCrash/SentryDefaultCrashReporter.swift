// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

#if !SDK_V10

/**
 * A wrapper around SentryCrash for testability.
 */
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
@objc @_spi(Private)
public class SentryDefaultCrashReporter: NSObject, SentryCrashReporter {
    private let bridge: SentryCrashBridge

    @objc
    public init(bridge: SentryCrashBridge) {
        self.bridge = bridge
        super.init()
    }
}
#else
@objc @_spi(Private)
public final class SentryDefaultCrashReporter: NSObject, SentryCrashReporter {
    private let bridge: SentryCrashBridge

    @objc
    public init(bridge: SentryCrashBridge) {
        self.bridge = bridge
        super.init()
    }
}
#endif

@_spi(Private) extension SentryDefaultCrashReporter {
    @objc
    public var installed: Bool {
        bridge.crashReporter.installed
    }

    @objc
    public var crashedLastLaunch: Bool {
        bridge.crashReporter.crashedLastLaunch
    }

    @objc
    public var durationFromCrashStateInitToLastCrash: TimeInterval {
        sentrycrashstate_currentState()?.pointee.durationFromCrashStateInitToLastCrash ?? 0
    }

    @objc
    public var activeDurationSinceLastCrash: TimeInterval {
        bridge.crashReporter.activeDurationSinceLastCrash
    }

    @objc
    public var isSimulatorBuild: Bool {
        sentrycrash_isSimulatorBuild()
    }

    @objc
    public var introspectMemory: Bool {
        get { bridge.crashReporter.introspectMemory }
        set { bridge.crashReporter.introspectMemory = newValue }
    }
}
// swiftlint:enable missing_docs
#endif // !SDK_V10
