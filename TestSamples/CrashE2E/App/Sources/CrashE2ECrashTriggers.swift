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
        case .cppExceptionV2DynamicImage:
            Thread.sleep(forTimeInterval: 2.0)
            CrashE2ERuntime.loadCPPExceptionImageAfterSDK()
            Thread.sleep(forTimeInterval: 0.5)
            CrashE2ETriggerDynamicCPPException()
            abortBecauseScenarioReturned(scenario)
        case .ignoredSignal:
            triggerIgnoredSignal()
        case .managedRuntimeClosedSignal:
            SentrySDK.close()
            SentrySDK.crash()
            abortBecauseScenarioReturned(scenario)
        case .managedRuntimeReinitSignal:
            CrashE2ERuntime.closeAndRestartSDK()
            SentrySDK.crash()
            abortBecauseScenarioReturned(scenario)
        case .nsException, .nsExceptionSubclass, .cppExceptionV1, .cppExceptionV2,
             .swiftAsyncCPPExceptionV2Off, .swiftAsyncCPPExceptionV2On, .unityCxaThrow,
             .unityCxaThrowV2, .objcObject, .objcObjectAfterCaughtCPP, .ksCrashRetryReportA,
             .ksCrashRetryReportB,
             .idle, .drain, .managedRuntimePreSDKSignal:
            triggerExceptionScenario(scenario)
        }
    }

    private static func triggerExceptionScenario(_ scenario: CrashE2EScenario) -> Never {
        switch scenario {
        case .nsException:
            NSException(
                name: NSExceptionName("CrashE2ENSException"),
                reason: "Crash E2E uncaught NSException",
                userInfo: ["scenario": scenario.rawValue]
            ).raise()
            abortBecauseScenarioReturned(scenario)
        case .nsExceptionSubclass:
            CrashE2ETriggerNSExceptionSubclass()
            abortBecauseScenarioReturned(scenario)
        case .ksCrashRetryReportA, .ksCrashRetryReportB:
            let marker = scenario == .ksCrashRetryReportA
                ? "crash-e2e-kscrash-report-a"
                : "crash-e2e-kscrash-report-b"
            NSException(
                name: NSExceptionName("CrashE2EKSCrashRetryReport"),
                reason: "Crash E2E KSCrash retry report \(marker)",
                userInfo: ["crash_e2e_kscrash_report": marker]
            ).raise()
            abortBecauseScenarioReturned(scenario)
        case .cppExceptionV1, .cppExceptionV2:
            CrashE2ETriggerCPPException()
            abortBecauseScenarioReturned(scenario)
        case .swiftAsyncCPPExceptionV2Off, .swiftAsyncCPPExceptionV2On:
            triggerSwiftAsyncCPPException(scenario)
        case .unityCxaThrow, .unityCxaThrowV2:
            CrashE2ETriggerUnitySentryCxaThrow()
            abortBecauseScenarioReturned(scenario)
        case .objcObject:
            // This is a modern C++ monitor scenario. The arbitrary Objective-C object throw is
            // expected to be reported by the C++ monitor, but the migration-sensitive contract is
            // for the throw-site-swapping path, not SentryCrash's weaker option-off report shape.
            CrashE2ETriggerObjCObjectException()
            abortBecauseScenarioReturned(scenario)
        case .objcObjectAfterCaughtCPP:
            // A caught C++ throw first populates the throw-site cursor. The later fatal arbitrary
            // Objective-C object must replace that cursor rather than report the stale C++ stack.
            CrashE2ETriggerObjCObjectAfterCaughtCPPException()
            abortBecauseScenarioReturned(scenario)
        case .idle, .drain, .managedRuntimePreSDKSignal:
            abortBecauseScenarioReturned(scenario)
        case .signal, .cppExceptionV2DynamicImage, .binaryImages, .ignoredSignal,
             .managedRuntimeSignalChain, .managedRuntimeClosedSignal, .managedRuntimeReinitSignal:
            abortBecauseScenarioReturned(scenario)
        }
    }

    private static func triggerIgnoredSignal() -> Never {
        NSLog("CrashE2E - raising pre-SDK ignored SIGPIPE")
        raise(SIGPIPE)
        NSLog("CrashE2E - ignored SIGPIPE did not terminate the process")
        exit(0)
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
