@testable import CrashE2ERunner
import Foundation
import XCTest

final class MacOSPlatformRunnerTests: XCTestCase {
    func testRunScenarios_whenExecutableIsMissing_shouldThrow() {
        // -- Arrange --
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        var config = Config(directories: Directories(crashE2EDir: directory, repoRoot: directory))
        config.scenarios = [.objcObject]

        let runner = MacOSPlatformRunner(config: config, processRunner: ProcessRunner())

        // -- Act & Assert --
        XCTAssertThrowsError(try runner.runScenarios()) { error in
            XCTAssertTrue(String(describing: error).contains("macOS executable not found"))
        }
    }
}
