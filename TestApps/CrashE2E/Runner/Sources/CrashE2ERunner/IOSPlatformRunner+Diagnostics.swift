import Foundation

extension IOSPlatformRunner {
    @discardableResult
    func runLoggedCommand(_ tool: String, _ arguments: [String], operation: String,
                          captureOutput: Bool = true, timeout: TimeInterval? = nil,
                          allowFailure: Bool = true, attempt: Int = 1, artifact: URL? = nil) throws -> ProcessResult {
        commandCount += 1
        let destination = artifact ?? config.artifactsDir
            .appendingPathComponent("ios-\(scenarioName)-commands")
            .appendingPathComponent("\(commandCount)-\(operation).log")
        let context = """
        Scenario: ios/\(scenarioName)
        Phase: \(phase.rawValue)
        App state: \(appState)
        Started: \(ISO8601DateFormatter().string(from: Date()))
        Attempt: \(attempt)
        Timeout: \(timeout.map { "\($0)s" } ?? "none")
        """
        let started = DispatchTime.now().uptimeNanoseconds

        log("[ios/\(scenarioName), \(phase.rawValue), \(appState)] \(operation) attempt \(attempt), timeout \(timeout.map { "\($0)s" } ?? "none")")

        do {
            let result = try processRunner.run(tool, arguments, captureOutput: captureOutput,
                                               timeout: timeout, allowFailure: allowFailure)
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000_000
            log("\(operation): \(result.summary); final termination \(result.terminationSummary); elapsed \(String(format: "%.3f", elapsed))s")
            saveDiagnostic("""
            \(context)
            Elapsed: \(elapsed)s
            Command: \(result.commandLine)
            Result: \(result.summary)
            Termination: \(result.terminationSummary)
            stdout:
            \(result.stdout)
            stderr:
            \(result.stderr)
            """, to: destination)
            return result
        } catch {
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000_000
            log("\(operation): command execution failed after \(String(format: "%.3f", elapsed))s: \(error)")
            saveDiagnostic("\(context)\nElapsed: \(elapsed)s\nTool: \(tool)\nArguments: \(arguments)\nError: \(error)\n", to: destination)
            throw error
        }
    }

    func recordScenarioFailure(_ error: Error) {
        let text = """
        Scenario: ios/\(scenarioName)
        Phase: \(phase.rawValue)
        App state: \(appState)
        Error: \(error)
        """
        log(text)
        saveDiagnostic(text, to: config.artifactsDir.appendingPathComponent("ios-\(scenarioName)-failure.log"))
        if error is SimulatorCommandFailure {
            let previousPhase = phase
            phase = .diagnostics
            captureHostHealth(in: config.artifactsDir.appendingPathComponent("ios-\(scenarioName)-environment"))
            phase = previousPhase
        }
    }

    func recordCleanupFailure(_ error: Error) {
        saveDiagnostic("Phase: cleanup\nApp state: \(appState)\nError: \(error)\n",
                       to: config.artifactsDir.appendingPathComponent("ios-\(scenarioName)-cleanup-failure.log"))
    }

    func recordTimeoutDiagnostics(process: ProcessExitObserver, timeout: TimeInterval) {
        guard let directory = launchArtifacts else { return }
        let text = """
        Scenario: ios/\(scenarioName)
        Phase: \(phase.rawValue)
        App state: \(appState)
        Failure: PID \(process.processIdentifier) did not exit within \(timeout)s
        """

        log(text)
        saveDiagnostic(text, to: directory.appendingPathComponent("timeout.log"))

        let previousPhase = phase
        phase = .diagnostics
        defer { phase = previousPhase }

        captureProcessState(process.processIdentifier, in: directory, filename: "process.log")

        // Host diagnostics remain available even when CoreSimulator is unresponsive.
        do {
            if try !process.wait(timeout: 0) {
                captureProcessStackshot(process.processIdentifier, in: directory)
            }

            if try process.wait(timeout: 0) {
                confirmAppStopped(pid: process.processIdentifier)
                saveDiagnostic("Exit confirmed during diagnostics; the original timeout still fails the scenario.\n",
                               to: directory.appendingPathComponent("process-after-stackshot.log"))
            } else {
                captureProcessState(process.processIdentifier, in: directory, filename: "process-after-stackshot.log")
            }
        } catch {
            log("Could not recheck iOS process during diagnostics: \(error)")
        }

        captureHostHealth(in: directory)
        captureSimulatorLaunchdState(in: directory)
    }

    private func captureHostHealth(in directory: URL) {
        captureDiagnostic("uptime", [], to: directory.appendingPathComponent("host-load.log"), timeout: 5)
        captureDiagnostic("vm_stat", [], to: directory.appendingPathComponent("host-memory.log"), timeout: 5)
    }

    private func captureProcessState(_ pid: Int32, in directory: URL, filename: String) {
        captureDiagnostic("ps", ["-p", String(pid), "-o", "pid,ppid,state,lstart,command"],
                          to: directory.appendingPathComponent(filename), timeout: 5)
    }

    private func captureProcessStackshot(_ pid: Int32, in directory: URL) {
        let output = directory.appendingPathComponent("stackshot.spindump")
        let budgetSeconds = 60

        // Kernel stackshots do not leave us responsible for resuming the target.
        // Request time for collection AND symbolication rather than killing its sudo
        // wrapper on a short deadline.
        // 
        // This is not an independent hard watchdog: the enclosing CI job remains the outer limit.
        //
        // A PID-reuse race is still possible: stacks are evidence, never a liveness signal.
        log("Collecting iOS kernel stacks (requested collection/symbolication budget: \(budgetSeconds)s).")
        do {
            let result = try runLoggedCommand(
                "sudo", ["-n", "/usr/sbin/spindump", String(pid), "2", "10", "-onlyTarget",
                         "-o", output.path, "-timelimit", String(budgetSeconds)],
                operation: "stackshot-command.log", artifact: directory.appendingPathComponent("stackshot-command.log")
            )
            let fileSize = (try? output.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            if !result.succeeded || fileSize == 0 {
                let evidence = fileSize == 0 ? "no nonempty stackshot was saved" : "retaining the report despite collector failure"
                let message = "Stackshot collection: \(result.summary); \(evidence).\n\(result.stderr)"
                log(message)
                saveDiagnostic(message, to: directory.appendingPathComponent("stackshot-unavailable.log"))
            }
        } catch {
            let message = "Could not start stackshot collection: \(error)"
            log(message)
            saveDiagnostic(message, to: directory.appendingPathComponent("stackshot-unavailable.log"))
        }
    }

    private func captureSimulatorLaunchdState(in directory: URL) {
        captureDiagnostic("xcrun", ["simctl", "spawn", deviceID, "launchctl", "list"],
                          to: directory.appendingPathComponent("launchctl.log"), timeout: 5)
    }

    func preserveFailureCache(scenario: Scenario) {
        guard let container = scenarioContainer else {
            log("No data container acquired for ios/\(scenario.rawValue); failure cache unavailable.")
            return
        }

        do {
            let cache = container.appendingPathComponent("Library/Caches", isDirectory: true)
            let destination = config.artifactsDir.appendingPathComponent("ios-\(scenario.rawValue)-failed-cache")
            try fileManager.ensureDirectory(at: destination)

            // The saved container belongs to this scenario. Snapshotting it requires no
            // further simulator query, which may itself have been the failing operation.
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
            try runLoggedCommand(tool, arguments, operation: url.lastPathComponent,
                                 timeout: timeout, artifact: url)
        } catch {
            log("Could not capture \(url.lastPathComponent): \(error)")
        }
    }

    private func saveDiagnostic(_ text: String, to url: URL) {
        do {
            try fileManager.ensureDirectory(at: url.deletingLastPathComponent())
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            log("Could not save \(url.path): \(error)")
        }
    }
}
