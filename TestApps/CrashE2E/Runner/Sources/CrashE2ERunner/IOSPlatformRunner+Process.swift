import Foundation

extension IOSPlatformRunner {
    func launchApp(arguments: [String]) throws -> ProcessResult {
        if let appProcess, try !appProcess.wait(timeout: 0) {
            try fail("Refusing to launch over running iOS PID \(appProcess.processIdentifier)")
        }

        appProcess = nil
        launchCount += 1
        let directory = config.artifactsDir.appendingPathComponent("ios-\(scenarioName)-launch-\(launchCount)")
        try fileManager.ensureDirectory(at: directory)
        launchArtifacts = directory

        let result = try processRunner.run(
            "xcrun",
            ["simctl", "launch",
             "--stdout=\(directory.appendingPathComponent("stdout.log").path)",
             "--stderr=\(directory.appendingPathComponent("stderr.log").path)",
             deviceID, bundleID, "--io.sentry.disable-http-transport"] + arguments,
            captureOutput: true,
            timeout: 30,
            allowFailure: true
        )
        defer {
            do {
                try writeProcessResult(result, to: directory.appendingPathComponent("launch.log"))
            } catch {
                log("Could not save iOS launch result: \(error)")
            }
        }

        // Register immediately: the app may already have exited by the time simctl returns.
        // This minimizes, but cannot eliminate, the pre-registration PID-reuse window.
        // Never infer an app's lifetime from the simctl command's own termination status.
        if result.succeeded {
            let pid = try ProcessExitObserver.launchedProcessIdentifier(stdout: result.stdout, bundleID: bundleID)
            appProcess = try ProcessExitObserver(processIdentifier: pid)
            log("Observing iOS PID \(pid); launch artifacts: \(directory.path)")
        }

        return result
    }

    func waitForAppToStop(timeout: TimeInterval) throws -> Bool {
        guard let appProcess else {
            try fail("Cannot wait for an iOS app without a successfully observed launch")
        }

        guard try appProcess.wait(timeout: timeout) else {
            recordTimeoutDiagnostics(process: appProcess, timeout: timeout)
            return false
        }

        return true
    }

    func terminateApp() throws {
        // A confirmed exit means this launch can no longer modify the shared cache,
        // even if its launchd job remains registered. No termination request is needed.
        if let appProcess, try appProcess.wait(timeout: 0) {
            self.appProcess = nil
            return
        }

        let commandOutcome = Result {
            try processRunner.run(
                "xcrun", ["simctl", "terminate", deviceID, bundleID],
                captureOutput: true, timeout: 10, allowFailure: true
            )
        }

        if let appProcess {
            guard try appProcess.wait(timeout: 5) else {
                let result = try commandOutcome.get()
                try fail("iOS PID \(appProcess.processIdentifier) survived cleanup (\(result.summary)): \(result.stderr)")
            }

            // simctl can fail independently of the app's lifetime. A confirmed process
            // exit establishes scenario isolation even when the termination request fails.
            switch commandOutcome {
            case .success(let result):
                if !result.succeeded {
                    log("iOS PID \(appProcess.processIdentifier) exited despite simctl terminate (\(result.summary)): \(result.stderr)")
                }
            case .failure(let error):
                log("iOS PID \(appProcess.processIdentifier) exited despite simctl terminate error: \(error)")
            }

            self.appProcess = nil

            return
        }

        // Without an observer, simctl's response is the only evidence of termination.
        // An explicit "no such process" response confirms absence; service errors
        // and timeouts do not.
        let result = try commandOutcome.get()
        let notRunning = !result.timedOut && result.terminationReason == .exit
            && result.terminationStatus == 3
            && result.stderr.contains("domain=NSPOSIXErrorDomain, code=3")
        guard result.succeeded || notRunning else {
            try fail("iOS cleanup simctl terminate failed (\(result.summary)): \(result.stderr)")
        }

        appProcess = nil
    }

    private func recordTimeoutDiagnostics(process: ProcessExitObserver, timeout: TimeInterval) {
        guard let directory = launchArtifacts else { return }

        log("iOS PID \(process.processIdentifier) did not exit within \(timeout)s. Saving diagnostics to \(directory.path)")

        captureProcessState(process.processIdentifier, in: directory)

        // Sample before invoking simctl: the simulator service itself may be the thing stuck.
        // Skip an exit already visible to the observer. Sampling by PID still has a small
        // exit/reuse race after this check, so the sample is diagnostic evidence only.
        do {
            if try !process.wait(timeout: 0) {
                captureProcessSample(process.processIdentifier, in: directory)
            }
        } catch {
            log("Could not recheck iOS process before sampling: \(error)")
        }

        captureSimulatorLaunchdState(in: directory)
    }

    private func captureProcessState(_ pid: Int32, in directory: URL) {
        captureDiagnostic("ps", ["-p", String(pid), "-o", "pid,ppid,state,lstart,command"],
                          to: directory.appendingPathComponent("process.log"), timeout: 5)
    }

    private func captureProcessSample(_ pid: Int32, in directory: URL) {
        captureDiagnostic("sample", [String(pid), "2", "-file", directory.appendingPathComponent("sample.txt").path],
                          to: directory.appendingPathComponent("sample-command.log"), timeout: 8)
    }

    private func captureSimulatorLaunchdState(in directory: URL) {
        captureDiagnostic("xcrun", ["simctl", "spawn", deviceID, "launchctl", "list"],
                          to: directory.appendingPathComponent("launchctl.log"), timeout: 5)
    }

    func preserveFailureCache(scenario: Scenario) {
        do {
            let cache = try dataContainer().appendingPathComponent("Library/Caches", isDirectory: true)
            let destination = config.artifactsDir.appendingPathComponent("ios-\(scenario.rawValue)-failed-cache")
            try fileManager.ensureDirectory(at: destination)

            // The process has been stopped before this snapshot. Preserve raw reports and
            // envelopes before the next scenario clears their shared container.
            for name in ["io.sentry", "KSCrash", "SentryCrash"] {
                let source = cache.appendingPathComponent(name)

                if fileManager.fileExists(atPath: source.path) {
                    try fileManager.copyItem(at: source, to: destination.appendingPathComponent(name))
                }
            }
        } catch {
            log("Could not preserve iOS failure cache: \(error)")
        }
    }

    private func captureDiagnostic(_ tool: String, _ arguments: [String], to url: URL, timeout: TimeInterval) {
        do {
            let result = try processRunner.run(tool, arguments, captureOutput: true,
                                               timeout: timeout, allowFailure: true)
            try writeProcessResult(result, to: url)
        } catch {
            log("Could not capture \(url.lastPathComponent): \(error)")
        }
    }

    private func writeProcessResult(_ result: ProcessResult, to url: URL) throws {
        let text = """
        Command: \(result.commandLine)
        Result: \(result.summary)
        stdout:
        \(result.stdout)
        stderr:
        \(result.stderr)
        """
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
