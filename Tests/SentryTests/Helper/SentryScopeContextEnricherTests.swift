@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

private final class TestSystemInfoProvider: SentrySystemInfoProvider {
    var value: SentrySystemInfo

    init(value: SentrySystemInfo) {
        self.value = value
    }

    func systemInfo() -> SentrySystemInfo {
        value
    }
}

private final class ScopeContextBinaryImageProvider: SentryBinaryImageProvider {
    private let images: [SentryBinaryImageInfo]

    init(images: [SentryBinaryImageInfo]) {
        self.images = images
    }

    func start(registry: SentryBinaryImageRegistry) {
        images.forEach(registry.binaryImageAdded)
    }

    func refresh() { }
    func stop() { }
}

final class SentryDefaultScopeContextEnricherTests: XCTestCase {
    private let defaultSystemInfo = SentrySystemInfo(
        systemName: "iOS",
        osBuild: "23A344",
        kernelVersion: "23.0.0",
        isJailbroken: false,
        cpuArchitecture: "arm64",
        machine: "iPhone14,2",
        model: "iPhone 13 Pro",
        freeMemorySize: 1_073_741_824,
        usableMemorySize: 4_294_967_296,
        memorySize: 6_442_450_944,
        appStartTime: "2023-01-01T12:00:00Z",
        deviceAppHash: "abc123",
        appID: "12345",
        buildType: "debug"
    )

    private func getSut(
        processInfo: MockSentryProcessInfo? = nil,
        systemInfo: SentrySystemInfo? = nil,
        screenSize: CGSize = .zero
    ) -> SentryDefaultScopeContextEnricher {
        let processInfo = processInfo ?? MockSentryProcessInfo()
        processInfo.overrides.isiOSAppOnMac = processInfo.overrides.isiOSAppOnMac ?? false
        processInfo.overrides.isMacCatalystApp = processInfo.overrides.isMacCatalystApp ?? false
        processInfo.overrides.isiOSAppOnVisionOS = processInfo.overrides.isiOSAppOnVisionOS ?? false

        return SentryDefaultScopeContextEnricher(
            processInfoWrapper: processInfo,
            systemInfoProvider: TestSystemInfoProvider(value: systemInfo ?? defaultSystemInfo),
            bundleInfo: [
                "CFBundleIdentifier": "io.sentry.crashTest",
                "CFBundleName": "CrashSentry",
                "CFBundleVersion": "201702072010",
                "CFBundleShortVersionString": "1.4.1"
            ],
            osVersionProvider: { "17.0.1" },
            screenSizeProvider: { screenSize }
        )
    }

    func testEnrichScopeSetsOSContext() throws {
        let scope = Scope()
        getSut().enrichScope(scope)

        let context = try XCTUnwrap(scope.contextDictionary["os"] as? [String: Any])
        XCTAssertEqual(context["name"] as? String, "iOS")
        XCTAssertEqual(context["version"] as? String, "17.0.1")
        XCTAssertEqual(context["build"] as? String, "23A344")
        XCTAssertEqual(context["kernel_version"] as? String, "23.0.0")
        XCTAssertEqual(context["rooted"] as? Bool, false)
    }

    func testEnrichScopeSetsDeviceContext() throws {
        let scope = Scope()
        getSut().enrichScope(scope)

        let context = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
#if targetEnvironment(macCatalyst)
        XCTAssertEqual(context["family"] as? String, "macOS")
#else
        XCTAssertEqual(context["family"] as? String, "iOS")
#endif
        XCTAssertEqual(context["arch"] as? String, "arm64")
        XCTAssertEqual(context["model"] as? String, "iPhone14,2")
        XCTAssertEqual(context["model_id"] as? String, "iPhone 13 Pro")
        XCTAssertEqual(context["free_memory"] as? UInt64, 1_073_741_824)
        XCTAssertEqual(context["usable_memory"] as? UInt64, 4_294_967_296)
        XCTAssertEqual(context["memory_size"] as? UInt64, 6_442_450_944)
#if SDK_V10
        XCTAssertNil(context["locale"])
#else
        XCTAssertNotNil(context["locale"])
#endif
#if targetEnvironment(simulator)
        XCTAssertEqual(context["simulator"] as? Bool, true)
#else
        XCTAssertEqual(context["simulator"] as? Bool, false)
#endif
    }

    func testEnrichScopeSetsAppContext() throws {
        let scope = Scope()
        getSut().enrichScope(scope)

        let context = try XCTUnwrap(scope.contextDictionary["app"] as? [String: Any])
        XCTAssertEqual(context["app_identifier"] as? String, "io.sentry.crashTest")
        XCTAssertEqual(context["app_name"] as? String, "CrashSentry")
        XCTAssertEqual(context["app_build"] as? String, "201702072010")
        XCTAssertEqual(context["app_version"] as? String, "1.4.1")
        XCTAssertEqual(context["app_start_time"] as? String, "2023-01-01T12:00:00Z")
        XCTAssertEqual(context["device_app_hash"] as? String, "abc123")
        XCTAssertEqual(context["app_id"] as? String, "12345")
        XCTAssertEqual(context["build_type"] as? String, "debug")
    }

    func testEnrichScopeSetsScreenDimensionsWhenAvailable() throws {
        let scope = Scope()
        getSut(screenSize: CGSize(width: 390, height: 844)).enrichScope(scope)

        let context = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertEqual(context["screen_width_pixels"] as? CGFloat, 390)
        XCTAssertEqual(context["screen_height_pixels"] as? CGFloat, 844)
    }

    func testEnrichScopeOmitsScreenDimensionsWhenUnavailable() throws {
        let scope = Scope()
        getSut().enrichScope(scope)

        let context = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertNil(context["screen_width_pixels"])
        XCTAssertNil(context["screen_height_pixels"])
    }

    func testEnrichScopeSetsOnlyTruePlatformFlags() throws {
        let processInfo = MockSentryProcessInfo()
        processInfo.overrides.isiOSAppOnMac = true
        processInfo.overrides.isMacCatalystApp = false
        processInfo.overrides.isiOSAppOnVisionOS = true
        let scope = Scope()

        getSut(processInfo: processInfo).enrichScope(scope)

        let context = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertEqual(context["ios_app_on_macos"] as? Bool, true)
        XCTAssertNil(context["mac_catalyst_app"])
        XCTAssertEqual(context["ios_app_on_visionos"] as? Bool, true)
    }

    func testEnrichScopeOmitsRuntimeForNativeApp() {
        let scope = Scope()
        getSut().enrichScope(scope)
        XCTAssertNil(scope.contextDictionary["runtime"])
    }

    func testEnrichScopeSetsIOSAppOnMacRuntime() throws {
        let processInfo = MockSentryProcessInfo()
        processInfo.overrides.isiOSAppOnMac = true
        let scope = Scope()

        getSut(processInfo: processInfo).enrichScope(scope)

        let context = try XCTUnwrap(scope.contextDictionary["runtime"] as? [String: String])
        XCTAssertEqual(context["name"], "iOS App on Mac")
        XCTAssertEqual(context["raw_description"], "ios-app-on-mac")
    }

    func testEnrichScopeSetsMacCatalystRuntime() throws {
        let processInfo = MockSentryProcessInfo()
        processInfo.overrides.isMacCatalystApp = true
        let scope = Scope()

        getSut(processInfo: processInfo).enrichScope(scope)

        let context = try XCTUnwrap(scope.contextDictionary["runtime"] as? [String: String])
        XCTAssertEqual(context["name"], "Mac Catalyst App")
        XCTAssertEqual(context["raw_description"], "mac-catalyst-app")
    }

    func testDefaultSystemInfoProviderProducesMeaningfulContext() throws {
        let binaryImageCache = SentryBinaryImageCache()
        binaryImageCache.start(false)
        let memoryMetricsProvider = SentryDefaultMemoryMetricsProvider()
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setDate(date: Date(timeIntervalSince1970: 1_700_000_000))
        let provider = SentryDefaultSystemInfoProvider(
            memoryMetricsProvider: memoryMetricsProvider,
            binaryImageCache: binaryImageCache,
            dateProvider: dateProvider,
            vendorIdentifierProvider: { UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF") }
        )

        let info = provider.systemInfo()

        XCTAssertFalse(info.systemName.isEmpty)
        XCTAssertFalse(info.osBuild.isEmpty)
        XCTAssertFalse(info.kernelVersion.isEmpty)
        XCTAssertFalse(info.cpuArchitecture.isEmpty)
        XCTAssertNotNil(info.machine)
        XCTAssertLessThanOrEqual(info.freeMemorySize, info.memorySize)
        XCTAssertGreaterThan(info.usableMemorySize, 0)
        XCTAssertGreaterThan(info.memorySize, 0)
        XCTAssertEqual(info.appStartTime, "2023-11-14T22:13:20Z")
        XCTAssertEqual(info.deviceAppHash.count, 40)
        XCTAssertFalse(info.buildType.isEmpty)
        XCTAssertNotNil(info.appID)

        dateProvider.setDate(date: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(provider.systemInfo().appStartTime, info.appStartTime)
    }

    func testDefaultSystemInfoProviderUsesMainExecutableUUIDForAppID() throws {
        let executablePath = try XCTUnwrap(Bundle.main.executablePath)
        let expectedUUID = "00112233-4455-6677-8899-AABBCCDDEEFF"
        let image = SentryBinaryImageInfo(
            name: executablePath,
            uuid: expectedUUID,
            vmAddress: 1,
            address: 1,
            size: 1
        )
        let binaryImageCache = SentryBinaryImageCache(
            provider: ScopeContextBinaryImageProvider(images: [image])
        )
        binaryImageCache.start(false)
        let provider = SentryDefaultSystemInfoProvider(
            memoryMetricsProvider: TestSentryMemoryMetricsProvider(),
            binaryImageCache: binaryImageCache,
            dateProvider: TestCurrentDateProvider()
        )

        XCTAssertEqual(provider.systemInfo().appID, expectedUUID)
    }
}
