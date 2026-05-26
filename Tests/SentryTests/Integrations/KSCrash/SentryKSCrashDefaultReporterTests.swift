@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryKSCrashDefaultReporterTests: XCTestCase {

    private var scope: Scope!

    private static let testSystemInfo: [String: Any] = [
        "osVersion": "23A344",
        "kernelVersion": "23.0.0",
        "isJailbroken": false,
        "systemName": "iOS",
        "cpuArchitecture": "arm64",
        "machine": "iPhone14,2",
        "model": "iPhone 13 Pro",
        // KSCrash uses "freeMemory" and "usableMemory" (not "freeMemorySize" / "usableMemorySize")
        "freeMemory": UInt64(1_073_741_824), // 1 GB
        "usableMemory": UInt64(4_294_967_296), // 4 GB
        "memorySize": UInt64(6_442_450_944), // 6 GB
        "appStartTime": "2023-01-01T12:00:00Z",
        "deviceAppHash": "abc123",
        "appID": "12345",
        "buildType": "debug"
    ]

    override func setUp() {
        super.setUp()
        scope = Scope()

#if (os(iOS) || os(tvOS) || os(visionOS)) && !targetEnvironment(macCatalyst)
        // Ensure UIDeviceWrapper info is initialized.
        // In production this is done at SentrySDKInternal, but tests may skip that.
        Dependencies.uiDeviceWrapper.start()
#endif
    }

    override func tearDown() {
        scope = nil
        super.tearDown()
    }

    // MARK: - crashedLastLaunch

    func test_crashedLastLaunch_matchesKSCrash() {
        let sut = makeSUT()
        // In test runs KSCrash.shared.crashedLastLaunch is false.
        XCTAssertFalse(sut.crashedLastLaunch)
    }

    // MARK: - durationFromCrashStateInitToLastCrash

    func test_durationFromCrashStateInitToLastCrash_isZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.durationFromCrashStateInitToLastCrash, 0)
    }

    // MARK: - isSimulatorBuild

    func test_isSimulatorBuild_matchesEnvironment() {
        let sut = makeSUT()
#if targetEnvironment(simulator)
        XCTAssertTrue(sut.isSimulatorBuild)
#else
        XCTAssertFalse(sut.isSimulatorBuild)
#endif
    }

    // MARK: - enrichScope OS context

    func test_enrichScope_setsOSName() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let os = try XCTUnwrap(scope.contextDictionary["os"] as? [String: Any])
        XCTAssertNotNil(os["name"])
    }

    func test_enrichScope_setsOSVersion() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let os = try XCTUnwrap(scope.contextDictionary["os"] as? [String: Any])
        XCTAssertNotNil(os["version"])
    }

    func test_enrichScope_setsOSBuildFromSystemInfo() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let os = try XCTUnwrap(scope.contextDictionary["os"] as? [String: Any])
        XCTAssertEqual(os["build"] as? String, "23A344")
    }

    func test_enrichScope_setsKernelVersionFromSystemInfo() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let os = try XCTUnwrap(scope.contextDictionary["os"] as? [String: Any])
        XCTAssertEqual(os["kernel_version"] as? String, "23.0.0")
    }

    func test_enrichScope_setsRootedFromSystemInfo() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let os = try XCTUnwrap(scope.contextDictionary["os"] as? [String: Any])
        XCTAssertEqual(os["rooted"] as? Bool, false)
    }

    // MARK: - enrichScope device context

    func test_enrichScope_setsCPUArchFromSystemInfo() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertEqual(device["arch"] as? String, "arm64")
    }

    func test_enrichScope_setsModelFromSystemInfo() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertEqual(device["model"] as? String, "iPhone14,2")
    }

    func test_enrichScope_setsModelIDFromSystemInfo() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertEqual(device["model_id"] as? String, "iPhone 13 Pro")
    }

    func test_enrichScope_setsFreeMemoryFromKSCrashKey() throws {
        // Validates that the reporter reads "freeMemory" (KSCrash key),
        // not the legacy "freeMemorySize" key used by the SentryCrash fork.
        let sut = makeSUT()
        sut.enrichScope(scope)
        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertEqual(device["free_memory"] as? UInt64, 1_073_741_824)
    }

    func test_enrichScope_setsUsableMemoryFromKSCrashKey() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertEqual(device["usable_memory"] as? UInt64, 4_294_967_296)
    }

    func test_enrichScope_setsMemorySizeFromSystemInfo() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertEqual(device["memory_size"] as? UInt64, 6_442_450_944)
    }

    func test_enrichScope_setsLocale() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertNotNil(device["locale"])
    }

    func test_enrichScope_setsSimulatorFlag() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        let simulator = device["simulator"] as? Bool
        XCTAssertNotNil(simulator)
#if targetEnvironment(simulator)
        XCTAssertTrue(simulator!)
#else
        XCTAssertFalse(simulator!)
#endif
    }

    func test_enrichScope_setsDeviceFamily() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
#if targetEnvironment(macCatalyst)
        XCTAssertEqual(device["family"] as? String, "macOS")
#else
        XCTAssertEqual(device["family"] as? String, "iOS")
#endif
    }

    // MARK: - enrichScope app context

    func test_enrichScope_setsAppStartTimeFromSystemInfo() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let app = try XCTUnwrap(scope.contextDictionary["app"] as? [String: Any])
        XCTAssertEqual(app["app_start_time"] as? String, "2023-01-01T12:00:00Z")
    }

    func test_enrichScope_setsDeviceAppHashFromSystemInfo() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let app = try XCTUnwrap(scope.contextDictionary["app"] as? [String: Any])
        XCTAssertEqual(app["device_app_hash"] as? String, "abc123")
    }

    func test_enrichScope_setsAppIDFromSystemInfo() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let app = try XCTUnwrap(scope.contextDictionary["app"] as? [String: Any])
        XCTAssertEqual(app["app_id"] as? String, "12345")
    }

    func test_enrichScope_setsBuildTypeFromSystemInfo() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let app = try XCTUnwrap(scope.contextDictionary["app"] as? [String: Any])
        XCTAssertEqual(app["build_type"] as? String, "debug")
    }

    func test_enrichScope_setsAppInfoFromBundle() throws {
        let sut = makeSUT()
        sut.enrichScope(scope)
        let app = try XCTUnwrap(scope.contextDictionary["app"] as? [String: Any])
        let infoDict = Bundle.main.infoDictionary ?? [:]
        XCTAssertEqual(app["app_identifier"] as? String, infoDict["CFBundleIdentifier"] as? String)
        XCTAssertEqual(app["app_name"] as? String, infoDict["CFBundleName"] as? String)
        XCTAssertEqual(app["app_build"] as? String, infoDict["CFBundleVersion"] as? String)
        XCTAssertEqual(app["app_version"] as? String, infoDict["CFBundleShortVersionString"] as? String)
    }

    // MARK: - enrichScope with empty systemInfo

    func test_enrichScope_withEmptySystemInfo_setsOSContextOnly() {
        let sut = SentryKSCrashDefaultReporter(
            processInfoWrapper: ProcessInfo.processInfo,
            systemInfo: [:]
        )
        sut.enrichScope(scope)
        // OS context is always set (name + version even without systemInfo)
        XCTAssertNotNil(scope.contextDictionary["os"])
        // Device and app context should NOT be set when systemInfo is empty
        XCTAssertNil(scope.contextDictionary["device"])
        XCTAssertNil(scope.contextDictionary["app"])
    }

    // MARK: - iOS-on-Mac / Mac Catalyst flags

    @available(macOS 12.0, *)
    func test_enrichScope_iOSAppOnMac_flagIsTrue() throws {
        let mockProcessInfo = MockSentryProcessInfo()
        mockProcessInfo.overrides.isiOSAppOnMac = true
        mockProcessInfo.overrides.isMacCatalystApp = false

        let sut = SentryKSCrashDefaultReporter(
            processInfoWrapper: mockProcessInfo,
            systemInfo: Self.testSystemInfo
        )
        sut.enrichScope(scope)

        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertEqual(device["ios_app_on_macos"] as? Bool, true)
        XCTAssertNil(device["mac_catalyst_app"])
    }

    @available(macOS 12.0, *)
    func test_enrichScope_macCatalyst_flagIsTrue() throws {
        let mockProcessInfo = MockSentryProcessInfo()
        mockProcessInfo.overrides.isiOSAppOnMac = false
        mockProcessInfo.overrides.isMacCatalystApp = true

        let sut = SentryKSCrashDefaultReporter(
            processInfoWrapper: mockProcessInfo,
            systemInfo: Self.testSystemInfo
        )
        sut.enrichScope(scope)

        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertNil(device["ios_app_on_macos"])
        XCTAssertEqual(device["mac_catalyst_app"] as? Bool, true)
    }

    func test_enrichScope_iOSAppOnVisionOS_flagIsTrue() throws {
        let mockProcessInfo = MockSentryProcessInfo()
        mockProcessInfo.overrides.isiOSAppOnVisionOS = true

        let sut = SentryKSCrashDefaultReporter(
            processInfoWrapper: mockProcessInfo,
            systemInfo: Self.testSystemInfo
        )
        sut.enrichScope(scope)

        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertEqual(device["ios_app_on_visionos"] as? Bool, true)
    }

    @available(macOS 12.0, *)
    func test_enrichScope_boolFlagsAbsentWhenFalse() throws {
        let mockProcessInfo = MockSentryProcessInfo()
        mockProcessInfo.overrides.isiOSAppOnMac = false
        mockProcessInfo.overrides.isMacCatalystApp = false
        mockProcessInfo.overrides.isiOSAppOnVisionOS = false

        let sut = SentryKSCrashDefaultReporter(
            processInfoWrapper: mockProcessInfo,
            systemInfo: Self.testSystemInfo
        )
        sut.enrichScope(scope)

        let device = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertNil(device["ios_app_on_macos"])
        XCTAssertNil(device["mac_catalyst_app"])
        XCTAssertNil(device["ios_app_on_visionos"])
    }

    // MARK: - systemInfo property

    func test_systemInfo_isExposedAsProperty() {
        let sut = makeSUT()
        XCTAssertEqual(sut.systemInfo["osVersion"] as? String, "23A344")
        XCTAssertEqual(sut.systemInfo["kernelVersion"] as? String, "23.0.0")
        XCTAssertEqual(sut.systemInfo["cpuArchitecture"] as? String, "arm64")
    }

    // MARK: - Helpers

    private func makeSUT() -> SentryKSCrashDefaultReporter {
        SentryKSCrashDefaultReporter(
            processInfoWrapper: ProcessInfo.processInfo,
            systemInfo: Self.testSystemInfo
        )
    }
}
