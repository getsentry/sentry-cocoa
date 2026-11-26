@testable import CrashE2ERunner
import XCTest

final class ConfigTests: XCTestCase {
    func testParse_whenHarnessTimeoutIsExplicit_shouldPreserveScenariosInEitherArgumentOrder() throws {
        // -- Arrange --
        let directories = Directories.discover()

        for reporter in Reporter.allCases {
            for scenarios in [["harness-timeout,signal"], ["harness-timeout", "signal"]] {
                let scenarioArguments = ["--scenarios"] + scenarios
                let reporterArguments = ["--reporter", reporter.rawValue]

                for arguments in [scenarioArguments + reporterArguments, reporterArguments + scenarioArguments] {
                    // -- Act --
                    let config = try Config.parse(arguments: arguments, directories: directories)

                    // -- Assert --
                    XCTAssertEqual(config.reporter, reporter)
                    XCTAssertEqual(config.scenarios.map(\.rawValue), ["harness-timeout", "signal"])
                }
            }
        }
    }

    func testParse_whenUsingDefaults_shouldExcludeHarnessTimeoutForBothReporters() throws {
        // -- Arrange --
        let directories = Directories.discover()
        let argumentLists = [
            [String](), ["--reporter", "SentryCrash"], ["--reporter", "KSCrash"],
            ["--reporter", "KSCrash", "--reporter", "SentryCrash"],
            ["--reporter", "SentryCrash", "--reporter", "KSCrash"]
        ]

        // -- Act --
        let configs = try argumentLists.map { try Config.parse(arguments: $0, directories: directories) }
        let defaults = [Config(directories: directories).scenarios,
                        Scenario.defaultScenarios, Scenario.ksCrashDefaultScenarios]

        // -- Assert --
        for scenarios in defaults + configs.map(\.scenarios) {
            XCTAssertFalse(scenarios.map(\.rawValue).contains("harness-timeout"))
            XCTAssertTrue(scenarios.contains(.signal))
        }
        for config in configs {
            XCTAssertEqual(config.scenarios, config.reporter == .ksCrash
                ? Scenario.ksCrashDefaultScenarios : Scenario.defaultScenarios)
        }
    }
}
