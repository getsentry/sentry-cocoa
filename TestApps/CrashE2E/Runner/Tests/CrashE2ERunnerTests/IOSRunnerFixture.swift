@testable import CrashE2ERunner
import Foundation
import XCTest

struct IOSRunnerFixture {
    let directory: URL
    let runner: IOSPlatformRunner
    let commands = CommandExecutorFake()

    init(pid: Int32, launchStatus: Int32 = 0, launchctlStatus: Int32 = 0, terminateStatus: Int32 = 0,
         cleanupStatus: Int32? = nil, reporter: Reporter = .ksCrash, scenarios: [Scenario] = [], keepGoing: Bool = false,
         onLaunch: @escaping (URL) throws -> Void = { _ in }, onTerminate: @escaping () -> Void = {}) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        self.directory = directory

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let bundleID = reporter.iOSBundleID
        var launched = false

        commands.handler = { call in
            if call.isCommand("xcrun", ["simctl", "launch"]) {
                launched = true
                try onLaunch(directory)
                return call.result(status: launchStatus, stdout: "\(bundleID): \(pid)\n")
            }

            if call.isCommand("xcrun", ["simctl", "get_app_container"]) {
                return call.result(stdout: directory.path + "\n")
            }

            if call.isCommand("xcrun", ["simctl", "terminate"]) {
                let status = launched ? cleanupStatus ?? terminateStatus : terminateStatus
                if status == 0 { onTerminate() }
                return call.result(status: status, stderr: status == 3 ? "domain=NSPOSIXErrorDomain, code=3" : "")
            }

            if call.isCommand("xcrun", ["simctl", "spawn"]) {
                // A stopped process's launchd job remains loaded indefinitely.
                let output = "PID\tStatus\tLabel\n-\t0\tUIKitApplication:\(bundleID)[123][rb-legacy]\n"
                return call.result(status: launchctlStatus, stdout: launchctlStatus == 0 ? output : "")
            }

            if call.isCommand("sudo", ["-n", "/usr/sbin/spindump"]) {
                let output = try XCTUnwrap(call.arguments.drop(while: { $0 != "-o" }).dropFirst().first)
                try "symbolicated stackshot\n".write(toFile: output, atomically: true, encoding: .utf8)
                return call.result()
            }

            if call.isCommand("xcrun", ["simctl", "install"]) || call.isCommand("xcrun", ["simctl", "uninstall"])
                || call.isCommand("ps")
                || call.isCommand("uptime") || call.isCommand("vm_stat") {
                return call.result()
            }

            XCTFail("Unexpected fixture command: \(call.tool) \(call.arguments)")
            throw CrashE2EFailure(message: "Unexpected fixture command")
        }

        var config = Config(directories: Directories(crashE2EDir: directory, repoRoot: directory))
        config.reporter = reporter
        config.scenarios = scenarios
        config.keepGoing = keepGoing

        let app = config.derivedDataPath.appendingPathComponent("Build/Products/Debug-iphonesimulator/\(reporter.iOSAppName)")

        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)

        runner = IOSPlatformRunner(config: config, processRunner: commands)
    }

    func remove() {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            XCTFail("Could not remove runner fixture: \(error)")
        }
    }
}
