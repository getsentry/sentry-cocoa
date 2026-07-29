import Foundation

extension MacOSPlatformRunner {
    func runKSCrashRetryScenario(executable: URL, cacheDir: URL,
                                 derivedDataPath: URL) throws {
        try prepareKSCrashRetryReportA(
            executable: executable,
            cacheDir: cacheDir,
            derivedDataPath: derivedDataPath
        )
        try prepareKSCrashRetryReportB(
            executable: executable,
            cacheDir: cacheDir,
            derivedDataPath: derivedDataPath
        )
        try runFirstKSCrashRetryDrain(
            executable: executable,
            cacheDir: cacheDir,
            derivedDataPath: derivedDataPath
        )
        try runSecondKSCrashRetryDrain(
            executable: executable,
            cacheDir: cacheDir,
            derivedDataPath: derivedDataPath
        )
        log("✅ macos/kscrash-per-report-retry assertions passed.")
    }

    private func prepareKSCrashRetryReportA(executable: URL, cacheDir: URL,
                                            derivedDataPath: URL) throws {
        try runKSCrashRetryProcess(
            appScenario: KSCrashRetryScenarioConstants.appScenarioA,
            faultMarker: nil,
            processingMarker: nil,
            phase: "prepare-a",
            expectsCrash: true,
            executable: executable,
            cacheDir: cacheDir,
            derivedDataPath: derivedDataPath
        )
        try assertKSCrashRetryState(
            pendingMarkers: [KSCrashRetryScenarioConstants.markerA],
            envelopeMarkers: [],
            cacheDir: cacheDir,
            phase: "prepare-a"
        )
    }

    private func prepareKSCrashRetryReportB(executable: URL, cacheDir: URL,
                                            derivedDataPath: URL) throws {
        let markerURL = cacheDir.appendingPathComponent(
            "crash-e2e-kscrash-retry-prepare-b.marker"
        )
        try runKSCrashRetryProcess(
            appScenario: KSCrashRetryScenarioConstants.appScenarioB,
            faultMarker: KSCrashRetryScenarioConstants.markerA,
            processingMarker: markerURL,
            phase: "prepare-b",
            expectsCrash: true,
            executable: executable,
            cacheDir: cacheDir,
            derivedDataPath: derivedDataPath
        )
        try assertKSCrashRetryState(
            pendingMarkers: [
                KSCrashRetryScenarioConstants.markerA,
                KSCrashRetryScenarioConstants.markerB
            ],
            envelopeMarkers: [],
            cacheDir: cacheDir,
            phase: "prepared"
        )
    }

    private func runFirstKSCrashRetryDrain(executable: URL, cacheDir: URL,
                                           derivedDataPath: URL) throws {
        let markerURL = cacheDir.appendingPathComponent(
            "crash-e2e-kscrash-retry-first-drain.marker"
        )
        try runKSCrashRetryProcess(
            appScenario: "drain",
            faultMarker: KSCrashRetryScenarioConstants.markerB,
            processingMarker: markerURL,
            phase: "first-drain",
            expectsCrash: false,
            executable: executable,
            cacheDir: cacheDir,
            derivedDataPath: derivedDataPath
        )
        try assertKSCrashRetryState(
            pendingMarkers: [KSCrashRetryScenarioConstants.markerB],
            envelopeMarkers: [KSCrashRetryScenarioConstants.markerA],
            cacheDir: cacheDir,
            phase: "first-drain"
        )
    }

    private func runSecondKSCrashRetryDrain(executable: URL, cacheDir: URL,
                                            derivedDataPath: URL) throws {
        let markerURL = cacheDir.appendingPathComponent(
            "crash-e2e-kscrash-retry-second-drain.marker"
        )
        try runKSCrashRetryProcess(
            appScenario: "drain",
            faultMarker: nil,
            processingMarker: markerURL,
            phase: "second-drain",
            expectsCrash: false,
            executable: executable,
            cacheDir: cacheDir,
            derivedDataPath: derivedDataPath
        )
        try assertKSCrashRetryState(
            pendingMarkers: [],
            envelopeMarkers: [
                KSCrashRetryScenarioConstants.markerA,
                KSCrashRetryScenarioConstants.markerB
            ],
            cacheDir: cacheDir,
            phase: "aggregate"
        )
    }

    private func assertKSCrashRetryState(pendingMarkers: [String], envelopeMarkers: [String],
                                         cacheDir: URL, phase: String) throws {
        try KSCrashRetryScenarioAsserter.assertPendingReports(
            pendingMarkers,
            cacheRoot: cacheDir,
            platform: "macos",
            phase: "kscrash-per-report-retry/\(phase)"
        )
        try KSCrashRetryScenarioAsserter.assertEnvelopeEvents(
            envelopeMarkers,
            cacheRoot: cacheDir,
            platform: "macos",
            phase: "kscrash-per-report-retry/\(phase)",
            artifactsDir: config.artifactsDir
        )
    }

    private func runKSCrashRetryProcess(
        appScenario: String,
        faultMarker: String?,
        processingMarker: URL?,
        phase: String,
        expectsCrash: Bool,
        executable: URL,
        cacheDir: URL,
        derivedDataPath: URL
    ) throws {
        if let processingMarker {
            try fileManager.removeItemIfExists(at: processingMarker)
        }
        var arguments = [
            "--io.sentry.disable-http-transport",
            "--cache-dir", cacheDir.path,
            "--scenario", appScenario
        ]
        appendKSCrashRetryArguments(
            faultMarker: faultMarker,
            processingMarker: processingMarker,
            to: &arguments
        )

        let processLog = config.artifactsDir.appendingPathComponent(
            "macos-kscrash-per-report-retry-\(phase).log"
        )
        let result = try processRunner.run(
            executable.path,
            arguments,
            environment: crashAppEnvironment(derivedDataPath: derivedDataPath),
            outputFile: processLog,
            timeout: 30,
            allowFailure: true
        )
        try assertKSCrashRetryProcessResult(
            result,
            expectsCrash: expectsCrash,
            processingMarker: processingMarker,
            phase: phase
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

    private func assertKSCrashRetryProcessResult(
        _ result: ProcessResult,
        expectsCrash: Bool,
        processingMarker: URL?,
        phase: String
    ) throws {
        if result.timedOut {
            try fail("macOS KSCrash retry \(phase) timed out (\(result.summary)).")
        }
        if expectsCrash == result.succeeded {
            try fail(
                "macOS KSCrash retry \(phase) had unexpected termination (\(result.summary))."
            )
        }
        if let processingMarker {
            try KSCrashRetryScenarioAsserter.assertProcessingCompleted(
                at: processingMarker,
                platform: "macos",
                phase: "kscrash-per-report-retry/\(phase)"
            )
        }
    }
}
