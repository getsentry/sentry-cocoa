@testable import CrashE2ERunner
import XCTest

final class ConfigTests: XCTestCase {
    func testParse_whenHarnessTimeoutIsExplicit_shouldPreserveScenariosInEitherArgumentOrder() throws {
        // -- Arrange --
        let directories = Directories.discover()

        for scenarios in [["harness-timeout,signal"], ["harness-timeout", "signal"]] {
            let scenarioArguments = ["--scenarios"] + scenarios
            let platformArguments = ["--platform", "ios"]

            for arguments in [scenarioArguments + platformArguments, platformArguments + scenarioArguments] {
                // -- Act --
                let config = try Config.parse(arguments: arguments, directories: directories)

                // -- Assert --
                XCTAssertEqual(config.platform, .ios)
                XCTAssertEqual(config.scenarios.map(\.rawValue), ["harness-timeout", "signal"])
            }
        }
    }

    func testParse_whenUsingDefaults_shouldIncludeAllDefaultCrashScenariosAndExcludeOptIns() throws {
        // -- Arrange --
        let directories = Directories.discover()
        let optInScenarios: Set<Scenario> = [.harnessTimeout, .mallocZoneLockedSignal]

        // -- Act --
        let parsed = try Config.parse(arguments: [], directories: directories)
        let initialized = Config(directories: directories)

        // -- Assert --
        XCTAssertEqual(parsed.scenarios, initialized.scenarios)
        XCTAssertEqual(parsed.scenarios, Scenario.defaultScenarios)
        XCTAssertEqual(Set(parsed.scenarios), Set(Scenario.allCases).subtracting(optInScenarios))
        XCTAssertEqual(parsed.scenarios.count, Set(parsed.scenarios).count)
    }
}
