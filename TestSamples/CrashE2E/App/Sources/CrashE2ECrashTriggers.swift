import Darwin
import Foundation
import Sentry

enum CrashE2ECrashTriggers {
    static func trigger(_ scenario: CrashE2EScenario) -> Never {
        switch scenario {
        case .signal, .managedRuntimeSignalChain:
            SentrySDK.crash()
            abortBecauseScenarioReturned(scenario)
        case .binaryImages:
            Thread.sleep(forTimeInterval: 2.0)
            CrashE2ERuntime.loadBinaryImageAfterSDKForCrashScenario()
            Thread.sleep(forTimeInterval: 0.5)
            CrashE2ETriggerDynamicBinaryImageCrash()
            abortBecauseScenarioReturned(scenario)
        case .managedRuntimeClosedSignal:
            SentrySDK.close()
            SentrySDK.crash()
            abortBecauseScenarioReturned(scenario)
        case .managedRuntimeReinitSignal:
            CrashE2ERuntime.closeAndRestartSDK()
            SentrySDK.crash()
            abortBecauseScenarioReturned(scenario)
        case .nsException:
            NSException(
                name: NSExceptionName("CrashE2ENSException"),
                reason: "Crash E2E uncaught NSException",
                userInfo: ["scenario": scenario.rawValue]
            ).raise()
            abortBecauseScenarioReturned(scenario)
        case .cppExceptionV1, .cppExceptionV2:
            CrashE2ETriggerCPPException()
            abortBecauseScenarioReturned(scenario)
        case .swiftAsyncCPPExceptionV2Off, .swiftAsyncCPPExceptionV2On:
            triggerSwiftAsyncCPPException(scenario)
        case .unityCxaThrow:
            CrashE2ETriggerUnitySentryCxaThrow()
            abortBecauseScenarioReturned(scenario)
        case .objcObject:
            // This is a modern C++ monitor scenario. The arbitrary Objective-C object throw is
            // expected to be reported by the C++ monitor, but the migration-sensitive contract is
            // for the V2/KSCrash path, not SentryCrash's legacy V1 fallback behavior.
            CrashE2ETriggerObjCObjectException()
            abortBecauseScenarioReturned(scenario)
        case .idle, .drain, .managedRuntimePreSDKSignal:
            abortBecauseScenarioReturned(scenario)
        }
    }

    private static func triggerSwiftAsyncCPPException(_ scenario: CrashE2EScenario) -> Never {
        // This is a swiftAsyncStacktraces test, not a C++ feature test. We use a C++ V2 throw as
        // the crash carrier because its throw-site capture goes through the SentryCrash/KSCrash
        // self-thread stack cursor, which is the migration-sensitive path toggled from plain
        // backtrace() to backtrace_async(). Signal crashes use the interrupted machine context, and
        // NSException usually uses NSException.callStackReturnAddresses, so neither reliably proves
        // that the public Swift async stitching option still affects crash-backend stack capture.
        Task.detached(priority: .userInitiated) {
            await swiftAsyncLevelOne(scenario)
        }
        while true {
            Thread.sleep(forTimeInterval: 1.0)
        }
    }

    @inline(never)
    private static func swiftAsyncLevelOne(_ scenario: CrashE2EScenario) async {
        await swiftAsyncLevelTwo(scenario)
    }

    @inline(never)
    private static func swiftAsyncLevelTwo(_ scenario: CrashE2EScenario) async {
        await swiftAsyncLevelThree(scenario)
    }

    @inline(never)
    private static func swiftAsyncLevelThree(_ scenario: CrashE2EScenario) async {
        try? await Task.sleep(nanoseconds: 10_000_000)
        CrashE2ETriggerCPPException()
        abortBecauseScenarioReturned(scenario)
    }

    private static func abortBecauseScenarioReturned(_ scenario: CrashE2EScenario) -> Never {
        NSLog("CrashE2E - scenario returned unexpectedly: \(scenario.rawValue)")
        Darwin.abort()
    }
}
