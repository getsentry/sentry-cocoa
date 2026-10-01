#if !SDK_V10
#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#endif
internal import _SentryPrivate
import Foundation

// MARK: - Dependency Provider

private final class SentryCrashV9Dependencies: SentryCrashV9IntegrationDependencies {
    private unowned let container: SentryDependencyContainer
    private var cachedCrashReporter: SentryCrashSwift?
    private var cachedCrashWrapper: SentryCrashReporter?
    private var crashInstallationReporter: SentryCrashInstallationReporter?

    init(container: SentryDependencyContainer) {
        self.container = container
    }

    var dateProvider: SentryCurrentDateProvider { container.dateProvider }
    var notificationCenterWrapper: SentryNSNotificationCenterWrapper {
        container.notificationCenterWrapper
    }

    var crashReporter: SentryCrashSwift {
        // Read container state before taking the store lock. The container's crashWrapper getter
        // takes its parameter lock before entering this store, so the opposite order could deadlock.
        let cacheDirectoryPath = container.startOptions?.cacheDirectoryPath
        return SentryCrashV9DependencyStore.withLock {
            getCrashReporter(cacheDirectoryPath: cacheDirectoryPath)
        }
    }

    var crashWrapper: SentryCrashReporter {
        let cacheDirectoryPath = container.startOptions?.cacheDirectoryPath
        let notificationCenterWrapper = container.notificationCenterWrapper
        let dateProvider = container.dateProvider
        return SentryCrashV9DependencyStore.withLock {
            getCrashWrapper(
                cacheDirectoryPath: cacheDirectoryPath,
                notificationCenterWrapper: notificationCenterWrapper,
                dateProvider: dateProvider
            )
        }
    }

    func getCrashInstallationReporter(_ options: Options) -> SentryCrashInstallationReporter {
        let crashWrapper = crashWrapper
        let dispatchQueue = container.dispatchQueueWrapper
        let replayRecoveryIdleGate = container.replayRecoveryIdleGate
        let inAppIncludes = options.inAppIncludes
        return SentryCrashV9DependencyStore.withLock {
            if let crashInstallationReporter {
                return crashInstallationReporter
            }
            let reporter = SentryCrashInstallationReporter(
                inAppLogic: SentryInAppLogic(inAppIncludes: inAppIncludes),
                crashWrapper: crashWrapper,
                dispatchQueue: dispatchQueue,
                startupCrashFlush: SentryStartupCrashFlush(idleGate: replayRecoveryIdleGate)
            )
            crashInstallationReporter = reporter
            return reporter
        }
    }

    func finalizePreviousRunSession(
        options: Options,
        crashedLastLaunch: Bool,
        activeDurationSinceLastCrash: TimeInterval
    ) {
        SentryCrashV9Backend.finalizePreviousRunSession(
            options: options,
            crashedLastLaunch: crashedLastLaunch,
            activeDurationSinceLastCrash: activeDurationSinceLastCrash,
            dependencies: container
        )
    }

    private func getCrashReporter(cacheDirectoryPath: String?) -> SentryCrashSwift {
        if let cachedCrashReporter {
            return cachedCrashReporter
        }
        let reporter = SentryCrashSwift(with: cacheDirectoryPath)
        cachedCrashReporter = reporter
        return reporter
    }

    private func getCrashWrapper(
        cacheDirectoryPath: String?,
        notificationCenterWrapper: SentryNSNotificationCenterWrapper,
        dateProvider: SentryCurrentDateProvider
    ) -> SentryCrashReporter {
        if let cachedCrashWrapper {
            return cachedCrashWrapper
        }
        let bridge = SentryCrashBridge(
            notificationCenterWrapper: notificationCenterWrapper,
            dateProvider: dateProvider,
            crashReporter: getCrashReporter(cacheDirectoryPath: cacheDirectoryPath)
        )
        let wrapper = SentryDefaultCrashReporter(bridge: bridge)
        cachedCrashWrapper = wrapper
        return wrapper
    }
}

private enum SentryCrashV9DependencyStore {
    private static let lock = NSRecursiveLock()
    private static let dependencies = NSMapTable<SentryDependencyContainer, SentryCrashV9Dependencies>
        .weakToStrongObjects()

    static func dependencies(for container: SentryDependencyContainer) -> SentryCrashV9Dependencies {
        withLock {
            if let dependencies = dependencies.object(forKey: container) {
                return dependencies
            }
            let newDependencies = SentryCrashV9Dependencies(container: container)
            dependencies.setObject(newDependencies, forKey: container)
            return newDependencies
        }
    }

    static func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try block()
    }
}

extension SentryDependencyContainer {
    /// The legacy recorder adapter associated with this dependency container.
    @_spi(Private) public var crashReporter: SentryCrashSwift {
        SentryCrashV9DependencyStore.dependencies(for: self).crashReporter
    }
}

// Export a C linking boundary without adding a public Swift or Objective-C API.
// Keep it ABI-visible so non-testable Xcode SwiftPM partial links do not localize the symbol
// before SentrySwift can resolve its cross-module call.
@usableFromInline
@_cdecl("sentrycrash_v9_registerSwiftBackend")
func sentrycrash_v9_registerSwiftBackend() {
    SentryCrashV9Backend.register(
        integrationInstaller: { options, dependencies in
            SentryCrashIntegration(
                with: options,
                dependencies: SentryCrashV9DependencyStore.dependencies(for: dependencies)
            )
        },
        crashWrapperProvider: { dependencies in
            SentryCrashV9DependencyStore.dependencies(for: dependencies).crashWrapper
        },
        exceptionCapture: { dependencies, exception in
            SentryCrashV9DependencyStore.dependencies(for: dependencies)
                .crashReporter.uncaughtExceptionHandler?(exception)
        }
    )
}
#endif // !SDK_V10
