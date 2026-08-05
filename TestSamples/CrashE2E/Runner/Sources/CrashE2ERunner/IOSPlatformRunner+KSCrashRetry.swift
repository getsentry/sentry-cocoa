import Foundation

extension IOSPlatformRunner {
    func runKSCrashRetryScenario(container: URL) throws {
        let cacheRoot = container.appendingPathComponent("Library/Caches", isDirectory: true)
        try processRunner.run(
            "xcrun",
            ["simctl", "terminate", deviceID, bundleID],
            captureOutput: true,
            allowFailure: true
        )

        try prepareKSCrashRetryReportA(cacheRoot: cacheRoot)
        try prepareKSCrashRetryReportB(cacheRoot: cacheRoot)
        try runFirstKSCrashRetryDrain(cacheRoot: cacheRoot)
        try runSecondKSCrashRetryDrain(cacheRoot: cacheRoot)
        log("✅ ios/kscrash-per-report-retry assertions passed.")
    }

    private func prepareKSCrashRetryReportA(cacheRoot: URL) throws {
        try runKSCrashRetryCrashLaunch(
            appScenario: KSCrashRetryScenarioConstants.appScenarioA,
            faultMarker: nil,
            processingMarker: nil,
            launchType: "prepare report A"
        )
        try KSCrashRetryScenarioAsserter.assertPendingReports(
            [KSCrashRetryScenarioConstants.markerA],
            cacheRoot: cacheRoot,
            platform: "ios",
            phase: "kscrash-per-report-retry/prepare-a"
        )
        try KSCrashRetryScenarioAsserter.assertEnvelopeEvents(
            [],
            cacheRoot: cacheRoot,
            platform: "ios",
            phase: "kscrash-per-report-retry/prepare-a",
            artifactsDir: config.artifactsDir
        )
    }

    private func prepareKSCrashRetryReportB(cacheRoot: URL) throws {
        let markerURL = cacheRoot.appendingPathComponent(
            "crash-e2e-kscrash-retry-prepare-b.marker"
        )
        try fileManager.removeItemIfExists(at: markerURL)
        try runKSCrashRetryCrashLaunch(
            appScenario: KSCrashRetryScenarioConstants.appScenarioB,
            faultMarker: KSCrashRetryScenarioConstants.markerA,
            processingMarker: markerURL,
            launchType: "prepare report B"
        )
        try KSCrashRetryScenarioAsserter.assertProcessingCompleted(
            at: markerURL,
            platform: "ios",
            phase: "kscrash-per-report-retry/prepare-b"
        )
        try KSCrashRetryScenarioAsserter.assertPendingReports(
            [KSCrashRetryScenarioConstants.markerA, KSCrashRetryScenarioConstants.markerB],
            cacheRoot: cacheRoot,
            platform: "ios",
            phase: "kscrash-per-report-retry/prepared"
        )
        try KSCrashRetryScenarioAsserter.assertEnvelopeEvents(
            [],
            cacheRoot: cacheRoot,
            platform: "ios",
            phase: "kscrash-per-report-retry/prepared",
            artifactsDir: config.artifactsDir
        )
    }

    private func runFirstKSCrashRetryDrain(cacheRoot: URL) throws {
        let markerURL = cacheRoot.appendingPathComponent(
            "crash-e2e-kscrash-retry-first-drain.marker"
        )
        try runKSCrashRetryDrainLaunch(
            faultMarker: KSCrashRetryScenarioConstants.markerB,
            processingMarker: markerURL,
            launchType: "first drain"
        )
        try KSCrashRetryScenarioAsserter.assertPendingReports(
            [KSCrashRetryScenarioConstants.markerB],
            cacheRoot: cacheRoot,
            platform: "ios",
            phase: "kscrash-per-report-retry/first-drain"
        )
        try KSCrashRetryScenarioAsserter.assertEnvelopeEvents(
            [KSCrashRetryScenarioConstants.markerA],
            cacheRoot: cacheRoot,
            platform: "ios",
            phase: "kscrash-per-report-retry/first-drain",
            artifactsDir: config.artifactsDir
        )
    }

    private func runSecondKSCrashRetryDrain(cacheRoot: URL) throws {
        let markerURL = cacheRoot.appendingPathComponent(
            "crash-e2e-kscrash-retry-second-drain.marker"
        )
        try runKSCrashRetryDrainLaunch(
            faultMarker: nil,
            processingMarker: markerURL,
            launchType: "second drain"
        )
        try KSCrashRetryScenarioAsserter.assertPendingReports(
            [],
            cacheRoot: cacheRoot,
            platform: "ios",
            phase: "kscrash-per-report-retry/second-drain"
        )
        try KSCrashRetryScenarioAsserter.assertEnvelopeEvents(
            [KSCrashRetryScenarioConstants.markerA, KSCrashRetryScenarioConstants.markerB],
            cacheRoot: cacheRoot,
            platform: "ios",
            phase: "kscrash-per-report-retry/aggregate",
            artifactsDir: config.artifactsDir
        )
    }

    private func runKSCrashRetryCrashLaunch(
        appScenario: String,
        faultMarker: String?,
        processingMarker: URL?,
        launchType: String
    ) throws {
        var arguments = ["--scenario", appScenario]
        appendKSCrashRetryArguments(
            faultMarker: faultMarker,
            processingMarker: processingMarker,
            to: &arguments
        )

        let result = try launchApp(arguments: arguments)
        try assertKSCrashRetryLaunchCompleted(result, launchType: launchType)
    }

    private func runKSCrashRetryDrainLaunch(
        faultMarker: String?,
        processingMarker: URL,
        launchType: String
    ) throws {
        try fileManager.removeItemIfExists(at: processingMarker)
        var arguments = ["--scenario", "drain"]
        appendKSCrashRetryArguments(
            faultMarker: faultMarker,
            processingMarker: processingMarker,
            to: &arguments
        )

        let result = try launchApp(arguments: arguments)
        try assertKSCrashRetryLaunchCompleted(result, launchType: launchType)
        try KSCrashRetryScenarioAsserter.assertProcessingCompleted(
            at: processingMarker,
            platform: "ios",
            phase: "kscrash-per-report-retry/\(launchType)"
        )
    }

    private func appendKSCrashRetryArguments(faultMarker: String?, processingMarker: URL?,
                                             to arguments: inout [String]) {
        if let faultMarker {
            arguments += [KSCrashRetryScenarioConstants.retryableMarkerArgument, faultMarker]
        }
        if let processingMarker {
            arguments += [
                KSCrashRetryScenarioConstants.processingCompleteMarkerArgument,
                processingMarker.path
            ]
        }
    }

    private func assertKSCrashRetryLaunchCompleted(_ result: ProcessResult,
                                                   launchType: String) throws {
        try assertLaunchSucceeded(
            result,
            scenario: .ksCrashPerReportRetry,
            launchType: launchType
        )
        guard try waitForAppToStop(timeout: 30) else {
            try fail("iOS app did not terminate during KSCrash retry \(launchType).")
        }
    }
}
