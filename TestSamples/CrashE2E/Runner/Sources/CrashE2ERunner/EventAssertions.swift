import Foundation

enum EventAssertions {
    private static let binaryImageMarkerFileName = "crash-e2e-binary-images.json"

    static func assertScenario(_ scenario: Scenario, platform: String, event: [String: Any],
                               cacheRoot: URL) throws {
        try assert(string(event["level"]) == "fatal", "Expected fatal event for \(platform)/\(scenario.rawValue)")

        let exceptionValues = valuesArray(event["exception"], key: "values")
        try assert(!exceptionValues.isEmpty, "Expected at least one exception for \(platform)/\(scenario.rawValue)")
        let firstException = exceptionValues[0]
        let mechanism = dictionary(firstException["mechanism"])

        try assert(bool(mechanism["handled"]) == false, "Expected unhandled exception for \(platform)/\(scenario.rawValue)")

        let debugImages = valuesArray(event["debug_meta"], key: "images")
        try assertDebugImages(debugImages, platform: platform, scenario: scenario)

        try assertThreadPayload(
            scenario,
            platform: platform,
            firstException: firstException,
            threadValues: valuesArray(event["threads"], key: "values")
        )
        try assertScenarioSpecificFields(
            scenario,
            platform: platform,
            firstException: firstException,
            mechanism: mechanism,
            debugImages: debugImages,
            cacheRoot: cacheRoot
        )
    }

    private static func assertThreadPayload(_ scenario: Scenario, platform: String,
                                            firstException: [String: Any],
                                            threadValues: [[String: Any]]) throws {
        let exceptionThreadID = int(firstException["thread_id"])
        switch scenario {
        case .cppExceptionV1, .unityCxaThrow:
            // Current SentryCrash C++ V1 can report the unhandled exception while omitting the
            // actual exception/main thread from threads.values, especially on iOS. The Unity smoke
            // intentionally runs in the same V1/fallback context because Sentry Unity does not
            // enable Sentry Cocoa's C++ V2 option today. Keep this escape hatch limited to these
            // V1-context scenarios; V1 is being sunset and KSCrash should not preserve this report
            // shape as parity behavior.
            try assert(exceptionThreadID != nil,
                       "Expected exception thread id for \(platform)/\(scenario.rawValue)")
            try assert(!threadValues.isEmpty, "Expected threads for \(platform)/\(scenario.rawValue)")
        case .cppExceptionV2, .swiftAsyncCPPExceptionV2Off,
             .swiftAsyncCPPExceptionV2On, .objcObject:
            try assert(exceptionThreadID != nil,
                       "Expected exception thread id for \(platform)/\(scenario.rawValue)")
            try assertCrashedThread(threadValues, expectedThreadID: exceptionThreadID,
                                    platform: platform, scenario: scenario)
        case .signal, .binaryImages, .managedRuntimeSignalChain, .managedRuntimePreSDKSignal,
             .managedRuntimeClosedSignal, .managedRuntimeReinitSignal, .nsException:
            try assertCrashedThread(threadValues, expectedThreadID: exceptionThreadID,
                                    platform: platform, scenario: scenario)
        }
    }

    private static func assertCrashedThread(_ threadValues: [[String: Any]], expectedThreadID: Int?,
                                            platform: String, scenario: Scenario) throws {
        let crashedThreads = threadValues.filter { bool($0["crashed"]) == true }
        try assert(!crashedThreads.isEmpty, "Expected crashed thread for \(platform)/\(scenario.rawValue)")

        if let expectedThreadID {
            try assert(crashedThreads.contains { int($0["id"]) == expectedThreadID },
                       "Expected exception thread \(expectedThreadID) to be marked crashed for \(platform)/\(scenario.rawValue)")
        }
    }

    private static func assertDebugImages(_ debugImages: [[String: Any]], platform: String,
                                          scenario: Scenario) throws {
        try assert(!debugImages.isEmpty, "Expected debug images for \(platform)/\(scenario.rawValue)")

        var seenImageKeys = Set<String>()
        for image in debugImages {
            guard let imageAddress = string(image["image_addr"]),
                  let codeFile = string(image["code_file"]) else {
                continue
            }
            let imageKey = "\(imageAddress)|\(codeFile)"
            try assert(seenImageKeys.insert(imageKey).inserted,
                       "Expected no duplicate debug image for \(platform)/\(scenario.rawValue): \(imageKey)")
        }
    }

    private static func assertScenarioSpecificFields(_ scenario: Scenario, platform: String,
                                                     firstException: [String: Any],
                                                     mechanism: [String: Any],
                                                     debugImages: [[String: Any]],
                                                     cacheRoot: URL) throws {
        switch scenario {
        case .signal, .binaryImages, .managedRuntimeSignalChain, .managedRuntimePreSDKSignal,
             .managedRuntimeClosedSignal, .managedRuntimeReinitSignal:
            let exceptionType = string(firstException["type"])
            let signalName = string(dictionary(dictionary(mechanism["meta"])["signal"])["name"])
            try assert(exceptionType == "EXC_BAD_ACCESS" || signalName == "SIGSEGV",
                       "Expected signal/mach exception for \(platform)/\(scenario.rawValue)")
            if scenario == .binaryImages {
                try assertBinaryImageScenario(debugImages, platform: platform, cacheRoot: cacheRoot)
            }

        case .nsException:
            try assert(string(firstException["type"]) == "CrashE2ENSException",
                       "Expected NSException type for \(platform)/ns-exception")

        case .cppExceptionV1, .cppExceptionV2, .swiftAsyncCPPExceptionV2Off:
            try assertCPPException(firstException, mechanism: mechanism, platform: platform,
                                   scenario: scenario, expectedValue: "CrashE2ECPPException")

        case .swiftAsyncCPPExceptionV2On:
            try assertCPPException(firstException, mechanism: mechanism, platform: platform,
                                   scenario: scenario, expectedValue: "CrashE2ECPPException")
            try assertSwiftAsyncFrames(firstException, platform: platform, scenario: scenario)

        case .unityCxaThrow:
            try assertCPPException(firstException, mechanism: mechanism, platform: platform,
                                   scenario: scenario, expectedValue: "CrashE2EUnitySentryCxaThrowException")

        case .objcObject:
            try assertObjCObjectThrow(firstException, mechanism: mechanism, platform: platform)
        }
    }

    private static func assertBinaryImageScenario(_ debugImages: [[String: Any]], platform: String,
                                                  cacheRoot: URL) throws {
        let markerURL = cacheRoot.appendingPathComponent(binaryImageMarkerFileName)
        guard FileManager.default.fileExists(atPath: markerURL.path) else {
            try fail("Expected binary image marker file for \(platform): \(markerURL.path)")
        }

        let data = try Data(contentsOf: markerURL)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let marker = jsonObject as? [String: Any],
              let beforeSDKPath = string(marker["before_sdk_path"]),
              let afterSDKPath = string(marker["after_sdk_path"]),
              !beforeSDKPath.isEmpty,
              !afterSDKPath.isEmpty else {
            try fail("Invalid binary image marker file for \(platform): \(markerURL.path)")
        }
        let codeFiles = debugImages.compactMap { string($0["code_file"]) }
        try assert(codeFiles.contains { isMainAppImage($0, platform: platform) },
                   "Expected main app image for \(platform)/binary-images")
        try assert(codeFiles.contains { isDyldImage($0) },
                   "Expected dyld image for \(platform)/binary-images")
        try assert(codeFiles.contains { isExpectedSystemImage($0) },
                   "Expected system image for \(platform)/binary-images")
        try assert(beforeSDKPath != afterSDKPath,
                   "Expected different before/after dynamic images for \(platform)/binary-images")
        try assert(debugImagesContainPath(debugImages, expectedPath: beforeSDKPath),
                   "Expected before-SDK dynamic image in debug images for \(platform): \(beforeSDKPath)")
        try assert(debugImagesContainPath(debugImages, expectedPath: afterSDKPath),
                   "Expected after-SDK dynamic image in debug images for \(platform): \(afterSDKPath)")
    }

    private static func assertSwiftAsyncFrames(_ firstException: [String: Any], platform: String,
                                               scenario: Scenario) throws {
        let frames = valuesArray(firstException["stacktrace"], key: "frames")
        let appFrames = frames.filter { string($0["package"])?.contains("CrashE2E-") == true }
        try assert(appFrames.count >= 4,
                   "Expected stitched Swift async app frames for \(platform)/\(scenario.rawValue)")

        let symbols = try symbolicatedFrameNames(appFrames)
        try assertFrameSymbolsContain(symbols, inOrder: [
            "triggerSwiftAsyncCPPException",
            "swiftAsyncLevelOne",
            "swiftAsyncLevelTwo",
            "swiftAsyncLevelThree",
            "CrashE2ETriggerCPPException"
        ], platform: platform, scenario: scenario)
    }

    private static func symbolicatedFrameNames(_ frames: [[String: Any]]) throws -> [String] {
        let processRunner = ProcessRunner()
        return try frames.map { frame in
            try processRunner.runOutput(
                "xcrun",
                ["atos", "-o", string(frame["package"]) ?? "",
                 "-l", string(frame["image_addr"]) ?? "",
                 string(frame["instruction_addr"]) ?? ""]
            )
        }
    }

    private static func assertFrameSymbolsContain(_ symbols: [String], inOrder expectedSymbols: [String],
                                                  platform: String, scenario: Scenario) throws {
        var searchStartIndex = symbols.startIndex
        for expectedSymbol in expectedSymbols {
            guard let matchIndex = symbols[searchStartIndex...]
                .firstIndex(where: { $0.contains(expectedSymbol) }) else {
                try fail("Expected symbol \(expectedSymbol) in \(platform)/\(scenario.rawValue) stack: \(symbols)")
            }
            searchStartIndex = symbols.index(after: matchIndex)
        }
    }

    private static func assertObjCObjectThrow(_ firstException: [String: Any], mechanism: [String: Any],
                                              platform: String) throws {
        try assert(string(firstException["type"]) == "C++ Exception",
                   "Expected Objective-C object throw to be reported by C++ monitor for \(platform)/objc-object")
        try assert(string(mechanism["type"]) == "cpp_exception",
                   "Expected C++ exception mechanism for \(platform)/objc-object")
        let value = string(firstException["value"]) ?? ""
        try assert(value.contains("CrashE2EThrownObject"),
                   "Expected thrown Objective-C object class in value for \(platform)/objc-object")
    }

    private static func assertCPPException(_ firstException: [String: Any], mechanism: [String: Any],
                                           platform: String, scenario: Scenario,
                                           expectedValue: String) throws {
        try assert(string(firstException["type"]) == "C++ Exception",
                   "Expected C++ exception type for \(platform)/\(scenario.rawValue)")
        try assert(string(mechanism["type"]) == "cpp_exception",
                   "Expected C++ exception mechanism for \(platform)/\(scenario.rawValue)")
        let value = string(firstException["value"]) ?? ""
        try assert(value.contains("runtime_error") && value.contains(expectedValue),
                   "Expected runtime_error value for \(platform)/\(scenario.rawValue)")
    }

    private static func debugImagesContainPath(_ debugImages: [[String: Any]], expectedPath: String) -> Bool {
        let expectedLastPathComponent = URL(fileURLWithPath: expectedPath).lastPathComponent
        return debugImages.contains { image in
            guard let codeFile = string(image["code_file"]) else { return false }
            let codeFileLastPathComponent = URL(fileURLWithPath: codeFile).lastPathComponent
            return codeFile == expectedPath
                || codeFile.hasSuffix(expectedPath)
                || expectedPath.hasSuffix(codeFile)
                || codeFileLastPathComponent == expectedLastPathComponent
        }
    }

    private static func isMainAppImage(_ codeFile: String, platform: String) -> Bool {
        let lastPathComponent = URL(fileURLWithPath: codeFile).lastPathComponent
        if platform == "ios" {
            return lastPathComponent == "CrashE2E-iOS"
                || lastPathComponent == "CrashE2E-iOS.debug.dylib"
        }
        return lastPathComponent == "CrashE2E-macOS"
    }

    private static func isDyldImage(_ codeFile: String) -> Bool {
        codeFile == "dyld" || codeFile.hasSuffix("/dyld") || codeFile.contains("/dyld_sim")
    }

    private static func isExpectedSystemImage(_ codeFile: String) -> Bool {
        codeFile.contains("Foundation.framework")
            || codeFile.contains("CoreFoundation.framework")
            || codeFile.contains("/System/Library/")
            || codeFile.contains("/usr/lib/")
    }

    private static func assert(_ condition: Bool, _ message: String) throws {
        guard condition else { throw CrashE2EFailure(message: message) }
    }

    private static func dictionary(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }

    private static func valuesArray(_ parent: Any?, key: String) -> [[String: Any]] {
        guard let dict = parent as? [String: Any], let values = dict[key] as? [Any] else {
            return []
        }
        return values.compactMap { $0 as? [String: Any] }
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func bool(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func isNull(_ value: Any?) -> Bool {
        value == nil || value is NSNull
    }
}
