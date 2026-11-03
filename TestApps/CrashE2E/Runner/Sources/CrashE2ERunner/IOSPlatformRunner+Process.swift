import Foundation

extension IOSPlatformRunner {
    func launchApp(arguments: [String]) throws -> ProcessResult {
        phase = .launch
        if let observer = appProcess {
            guard try observer.wait(timeout: 0) else {
                try fail("Refusing to launch over running iOS PID \(observer.processIdentifier)")
            }
            confirmAppStopped(pid: observer.processIdentifier)
        }

        launchCount += 1
        let directory = config.artifactsDir.appendingPathComponent("ios-\(scenarioName)-launch-\(launchCount)")
        try fileManager.ensureDirectory(at: directory)
        launchArtifacts = directory

        // A failed or timed-out launch command may still have started an app. Its state
        // remains unknown until a PID is observed or termination is confirmed.
        appState = .unknown
        let result = try runLoggedCommand(
            "xcrun",
            ["simctl", "launch",
             "--stdout=\(directory.appendingPathComponent("stdout.log").path)",
             "--stderr=\(directory.appendingPathComponent("stderr.log").path)",
             deviceID, bundleID, "--io.sentry.disable-http-transport"] + arguments,
            operation: "launch", timeout: 30, artifact: directory.appendingPathComponent("launch.log")
        )

        // Register immediately: the app may already have exited by the time simctl returns.
        // This minimizes, but cannot eliminate, the pre-registration PID-reuse window.
        if result.succeeded {
            let pid = try ProcessExitObserver.launchedProcessIdentifier(stdout: result.stdout, bundleID: bundleID)
            appState = .observed(try ProcessExitObserver(processIdentifier: pid))
            log("Observing iOS PID \(pid); launch artifacts: \(directory.path)")
        }
        return result
    }

    func waitForAppToStop(timeout: TimeInterval) throws -> Bool {
        phase = .waitingForExit
        if case .stopped = appState {
            log("iOS app stop already confirmed: \(appState).")
            return true
        }
        guard let observer = appProcess else {
            try fail("Cannot wait for an iOS app without a successfully observed launch")
        }

        log("Waiting up to \(timeout)s for iOS PID \(observer.processIdentifier) to exit.")
        guard try observer.wait(timeout: timeout) else {
            recordTimeoutDiagnostics(process: observer, timeout: timeout)
            return false
        }
        confirmAppStopped(pid: observer.processIdentifier)
        return true
    }

    func confirmAppStopped(pid: Int32?) {
        appState = .stopped(lastPID: pid)
        log("[ios/\(scenarioName), \(phase.rawValue)] App state: \(appState)")
    }

    func terminateApp() throws {
        let previousPhase = phase
        phase = .cleanup
        defer { phase = previousPhase }

        // Stop confirmation remains valid until this runner requests another launch.
        // A loaded launchd job does not invalidate an observed process exit.
        if case .stopped = appState { return }
        if let observer = appProcess, try observer.wait(timeout: 0) {
            confirmAppStopped(pid: observer.processIdentifier)
            return
        }

        for (index, timeout) in Self.simulatorCommandTimeouts.enumerated() {
            let commandOutcome = Result {
                try runLoggedCommand("xcrun", ["simctl", "terminate", deviceID, bundleID],
                                     operation: "terminate", timeout: timeout, attempt: index + 1)
            }
            if let observer = appProcess, try observer.wait(timeout: 5) {
                // simctl can fail independently of the app's lifetime. A confirmed exit
                // establishes isolation even when the termination request fails.
                confirmAppStopped(pid: observer.processIdentifier)
                return
            }

            let result = try commandOutcome.get()
            let notRunning = !result.timedOut && result.terminationReason == .exit
                && result.terminationStatus == 3
                && result.stderr.contains("domain=NSPOSIXErrorDomain, code=3")
            if appProcess == nil, result.succeeded || notRunning {
                confirmAppStopped(pid: nil)
                return
            }

            // Termination is idempotent. Retrying its control-command timeout cannot
            // rerun a crash or turn the original scenario failure into success.
            if result.timedOut, index + 1 < Self.simulatorCommandTimeouts.count {
                log("Retrying simulator termination after control-command timeout; app state: \(appState)")
                continue
            }
            if let observer = appProcess {
                try fail("iOS PID \(observer.processIdentifier) survived cleanup (\(result.summary)): \(result.stderr)")
            }
            throw SimulatorCommandFailure(message: "iOS cleanup simctl terminate failed (\(result.summary)): \(result.stderr)")
        }
    }
}
