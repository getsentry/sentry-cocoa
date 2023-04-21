import Foundation
import Sentry

public class TestCrashWrapper: SentryCrashWrapper {
    public var internalCrashedLastLaunch: Bool = false
    public var internalDurationFromCrashStateInitToLastCrash: TimeInterval = 0
    public var internalActiveDurationSinceLastCrash: TimeInterval = 0
    public var internalIsBeingTraced: Bool = false
    public var internalIsSimulatorBuild: Bool = false
    public var internalIsApplicationInForeground: Bool = true
    public var installAsyncHooksCalled: Bool = false
    public var uninstallAsyncHooksCalled: Bool = false
    public var internalFreeMemorySize: UInt64 = 0
    public var internalAppMemorySize: UInt64 = 0
    public var internalFreeStorageSize: UInt64 = 0

    public override init() {}

    public override func crashedLastLaunch() -> Bool {
        internalCrashedLastLaunch
    }

    public override func durationFromCrashStateInitToLastCrash() -> TimeInterval {
        internalDurationFromCrashStateInitToLastCrash
    }

    public override func activeDurationSinceLastCrash() -> TimeInterval {
        internalActiveDurationSinceLastCrash
    }

    public override func isBeingTraced() -> Bool {
        internalIsBeingTraced
    }

    public override func isSimulatorBuild() -> Bool {
        internalIsSimulatorBuild
    }

    public override func isApplicationInForeground() -> Bool {
        internalIsApplicationInForeground
    }

    public override func installAsyncHooks() {
        installAsyncHooksCalled = true
    }

    public override func uninstallAsyncHooks() {
        uninstallAsyncHooksCalled = true
    }

    public override func freeMemorySize() -> bytes {
        internalFreeMemorySize
    }

    public override func appMemorySize() -> bytes {
        internalAppMemorySize
    }

    public override func freeStorageSize() -> bytes {
        internalFreeStorageSize
    }
}
