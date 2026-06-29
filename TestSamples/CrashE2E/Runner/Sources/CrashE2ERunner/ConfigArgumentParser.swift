import Foundation

private enum ValueOption: String {
    case platform = "--platform"
    case scenarios = "--scenarios"
    case iosDestination = "--ios-destination"
    case iosDeviceID = "--ios-device-id"
    case derivedDataPath = "--derived-data-path"
    case artifactsDir = "--artifacts-dir"
}

private enum FlagOption: String {
    case skipBuild = "--skip-build"
    case keepArtifacts = "--keep-artifacts"
    case keepGoing = "--keep-going"
    case quietBuild = "--quiet-build"
}

struct ConfigArgumentParser {
    private let arguments: [String]
    private var config: Config
    private var index = 0

    init(arguments: [String], directories: Directories) {
        self.arguments = arguments
        self.config = Config(directories: directories)
    }

    mutating func parse() throws -> Config {
        while index < arguments.count {
            try parseCurrentArgument()
        }
        return config
    }

    private mutating func parseCurrentArgument() throws {
        let argument = arguments[index]
        if argument == "--help" || argument == "-h" {
            throw HelpRequested()
        }
        if argument == "-k" || argument == "--continue-on-error" {
            config.keepGoing = true
            index += 1
            return
        }
        if let option = ValueOption(rawValue: argument) {
            try parseValueOption(option)
            return
        }
        if let option = FlagOption(rawValue: argument) {
            parseFlagOption(option)
            return
        }
        throw CrashE2EFailure(message: "Unknown option: \(argument)")
    }

    private mutating func parseValueOption(_ option: ValueOption) throws {
        switch option {
        case .platform:
            try parsePlatform()
        case .scenarios:
            try parseScenarios()
        case .iosDestination:
            config.iosDestination = try valueAfterCurrentArgument()
            index += 2
        case .iosDeviceID:
            config.iosDeviceID = try valueAfterCurrentArgument()
            index += 2
        case .derivedDataPath:
            config.derivedDataPath = absoluteURL(try valueAfterCurrentArgument())
            index += 2
        case .artifactsDir:
            config.artifactsDir = absoluteURL(try valueAfterCurrentArgument())
            index += 2
        }
    }

    private mutating func parseFlagOption(_ option: FlagOption) {
        switch option {
        case .skipBuild:
            config.skipBuild = true
        case .keepArtifacts:
            config.keepArtifacts = true
        case .keepGoing:
            config.keepGoing = true
        case .quietBuild:
            config.quietBuild = true
        }
        index += 1
    }

    private mutating func parsePlatform() throws {
        let value = try valueAfterCurrentArgument()
        guard let platform = Platform(rawValue: value) else {
            throw CrashE2EFailure(message: "Invalid --platform: \(value)")
        }
        config.platform = platform
        index += 2
    }

    private mutating func parseScenarios() throws {
        let values = try scenarioArgumentValues()
        let scenarioNames = values.flatMap(splitScenarioNames)
        guard !scenarioNames.isEmpty else {
            throw CrashE2EFailure(message: "--scenarios must not be empty")
        }
        config.scenarios = try scenarioNames.map(parseScenario)
    }

    private mutating func scenarioArgumentValues() throws -> [String] {
        var values = [try valueAfterCurrentArgument()]
        var nextIndex = index + 2
        while nextIndex < arguments.count, !arguments[nextIndex].hasPrefix("-") {
            values.append(arguments[nextIndex])
            nextIndex += 1
        }
        index = nextIndex
        return values
    }

    private func splitScenarioNames(_ value: String) -> [String] {
        value.split(whereSeparator: { $0 == " " || $0 == "," || $0 == ";" })
            .map(String.init)
    }

    private func parseScenario(_ name: String) throws -> Scenario {
        guard let scenario = Scenario(rawValue: name) else {
            throw CrashE2EFailure(message: "Unknown scenario: \(name)")
        }
        return scenario
    }

    private func valueAfterCurrentArgument() throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw CrashE2EFailure(message: "Missing value after \(arguments[index])")
        }
        return arguments[valueIndex]
    }
}
