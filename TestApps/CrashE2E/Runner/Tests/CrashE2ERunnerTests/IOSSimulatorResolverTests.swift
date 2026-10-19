@testable import CrashE2ERunner
import XCTest

final class IOSSimulatorResolverTests: XCTestCase {
    func testResolve_whenDeviceIsAvailable_shouldUseCapturedCommandOutput() throws {
        // -- Arrange --
        let commands = CommandExecutorFake()
        commands.handler = { call in
            XCTAssertEqual(call.tool, "xcrun")
            XCTAssertEqual(call.arguments, ["simctl", "list", "devices", "available", "-j"])
            XCTAssertTrue(call.captureOutput)
            XCTAssertFalse(call.allowFailure)
            return call.result(stdout: """
            {
                "devices": {
                    "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
                        {"name": "iPhone 17 Pro", "udid": "test-device", "state": "Booted", "isAvailable": true}
                    ]
                }
            }
            """)
        }

        let resolver = IOSSimulatorResolver(processRunner: commands)

        // -- Act --
        let selection = try resolver.resolve(deviceID: "test-device", destination: nil)

        // -- Assert --
        XCTAssertEqual(selection.device.udid, "test-device")
        XCTAssertEqual(selection.device.state, "Booted")
        XCTAssertEqual(selection.xcodebuildDestination, "id=test-device")
        XCTAssertEqual(commands.calls.count, 1)
    }
}
