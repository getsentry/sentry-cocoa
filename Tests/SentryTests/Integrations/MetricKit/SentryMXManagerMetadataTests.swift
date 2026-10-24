@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

/// Covers how `SentryMXManager` tells diagnostics of a previous process from the current one and
/// which metadata it gives their events.
final class SentryMXManagerMetadataTests: SentrySDKIntegrationTestsBase {

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - the SDK is started with a hub per test.
        clearTestState()
    }

    // MARK: - Diagnostics from a previous process

    func testDidReceive_whenDiagnosticPidDiffers_shouldMarkEventAsFromPreviousProcess() throws {
        try requirePidSupport()
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        // The payload window opened in this run, but MetricKit knows the diagnostic's process.
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20", pid: Self.previousProcessPid, timeStampBegin: Self.processStartDate.addingTimeInterval(60))

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, scope, _ in
            XCTAssertEqual(event?.isFromPreviousProcess, true)
            // The hub's scope is passed through untouched; the client leaves it out for the event.
            XCTAssertTrue(scope === SentrySDKInternal.currentHub().scope)
        }
    }

    func testDidReceive_whenDiagnosticPidMatches_shouldKeepEventInCurrentAppRun() throws {
        try requirePidSupport()
        // -- Arrange --
        givenSDKWithHubWithScope(appContext: Self.runningAppContext, osContext: Self.runningOSContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        // The payload window opened before the process started, but MetricKit knows the process.
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20", pid: Self.currentPid, timeStampBegin: Self.processStartDate.addingTimeInterval(-60))

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, scope, _ in
            XCTAssertEqual(event?.isFromPreviousProcess, false)
            XCTAssertNil(event?.context)
            XCTAssertNil(event?.releaseName)
            XCTAssertNil(event?.dist)
            XCTAssertTrue(scope === SentrySDKInternal.currentHub().scope)
        }
    }

    func testDidReceive_whenNoPidAndPayloadStartsBeforeProcess_shouldMarkEventAsFromPreviousProcess() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20", pid: 0, timeStampBegin: Self.processStartDate.addingTimeInterval(-1))

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.isFromPreviousProcess, true)
        }
    }

    func testDidReceive_whenNoPidAndPayloadStartsAfterProcess_shouldKeepEventInCurrentAppRun() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(appContext: Self.runningAppContext, osContext: Self.runningOSContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20", pid: 0, timeStampBegin: Self.processStartDate)

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.isFromPreviousProcess, false)
            XCTAssertNil(event?.context)
        }
    }

    func testDidReceive_whenDiagnosticFromPreviousAppVersion_shouldSetReleaseAndDistFromDiagnostic() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "1.2.3", appBuild: "45")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.releaseName, "io.sentry.app@1.2.3+45")
            XCTAssertEqual(event?.dist, "45")
        }
    }

    func testDidReceive_whenDiagnosticFromPreviousBuild_shouldSetReleaseAndDistFromDiagnostic() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "19")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.releaseName, "io.sentry.app@2.0.0+19")
            XCTAssertEqual(event?.dist, "19")
        }
    }

    func testDidReceive_whenDiagnosticFromCurrentAppVersion_shouldNotSetReleaseAndDist() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        // The client applies the running release, which matches the diagnostic.
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.isFromPreviousProcess, true)
            XCTAssertNil(event?.releaseName)
            XCTAssertNil(event?.dist)
        }
    }

    func testDidReceive_whenCustomReleaseNameAndDiagnosticFromPreviousAppVersion_shouldNotSetReleaseAndDist() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let sut = givenSut(releaseName: "my-custom-release")
        let payload = try givenHangPayload(appVersion: "1.2.3", appBuild: "45")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNil(event?.releaseName)
            XCTAssertNil(event?.dist)
        }
    }

    func testDidReceive_whenDiagnosticHasMetadata_shouldSetAppAndOSContextOnEvent() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(appContext: Self.runningAppContext, osContext: Self.runningOSContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "1.2.3", appBuild: "45", osVersion: "iPhone OS 18.6.2 (22G100)")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            // The client doesn't apply the scope to the event, so the contexts live on the event,
            // reduced to what is known for the diagnostic.
            XCTAssertEqual(event?.context?["app"] as NSDictionary?, [
                "app_identifier": "io.sentry.app",
                "app_version": "1.2.3",
                "app_build": "45"
            ])
            XCTAssertEqual(event?.context?["os"] as NSDictionary?, [
                "name": "iOS",
                "version": "18.6.2",
                "build": "22G100"
            ])
        }
        let hubScope = SentrySDKInternal.currentHub().scope
        XCTAssertEqual(hubScope.getContextForKey("app") as NSDictionary?, Self.runningAppContext as NSDictionary)
        XCTAssertEqual(hubScope.getContextForKey("os") as NSDictionary?, Self.runningOSContext as NSDictionary)
    }

    func testDidReceive_whenDiagnosticHasOnlyAppVersion_shouldSetAppContextWithoutBuild() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(appContext: Self.runningAppContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "1.2.3", appBuild: "")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.context?["app"] as NSDictionary?, [
                "app_identifier": "io.sentry.app",
                "app_version": "1.2.3"
            ])
        }
    }

    func testDidReceive_whenScopeHasNoAppContext_shouldSetAppVersionAndBuildOnEvent() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        SentrySDKInternal.currentHub().scope.removeContext(key: "app")
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "1.2.3", appBuild: "45")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.context?["app"] as NSDictionary?, ["app_version": "1.2.3", "app_build": "45"])
        }
    }

    func testDidReceive_whenOSVersionHasNoBuild_shouldSetOSContextWithoutBuild() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(osContext: Self.runningOSContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20", osVersion: "macOS 14.1")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.context?["os"] as NSDictionary?, ["name": "iOS", "version": "14.1"])
        }
    }

    func testDidReceive_whenScopeHasNoOSContext_shouldSetOSVersionAndBuildOnEvent() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        SentrySDKInternal.currentHub().scope.removeContext(key: "os")
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20", osVersion: "iPhone OS 18.6.2 (22G100)")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.context?["os"] as NSDictionary?, ["version": "18.6.2", "build": "22G100"])
        }
    }

    func testDidReceive_whenOSVersionIsUnparseable_shouldOnlySetOSName() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(osContext: Self.runningOSContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20", osVersion: "unknown")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        // The running OS version isn't known to apply to the diagnostic, so it stays out.
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.context?["os"] as NSDictionary?, ["name": "iOS"])
        }
    }

    func testDidReceive_whenDiagnosticHasNoMetadata_shouldNotSetReleaseAndDist() throws {
        // -- Arrange --
        givenSDKWithHubWithScope(appContext: Self.runningAppContext, osContext: Self.runningOSContext)
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]
        payload.overrides.timeStampBegin = Self.processStartDate.addingTimeInterval(-3_600)

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.isFromPreviousProcess, true)
            XCTAssertNil(event?.releaseName)
            XCTAssertNil(event?.dist)
            // Only the attributes that don't depend on the app version or the OS remain.
            XCTAssertEqual(event?.context?["app"] as NSDictionary?, ["app_identifier": "io.sentry.app"])
            XCTAssertEqual(event?.context?["os"] as NSDictionary?, ["name": "iOS"])
        }
    }

    func testDidReceive_whenDiagnosticFromPreviousProcess_shouldKeepOnlyStableDeviceContext() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        SentrySDKInternal.currentHub().scope.setContext(value: [
            "arch": "arm64e",
            "family": "iOS",
            "model": "iPhone17,1",
            "model_id": "D93AP",
            "simulator": false,
            "memory_size": 8_000_000_000,
            "screen_height_pixels": 2_622,
            "screen_width_pixels": 1_206,
            "ios_app_on_macos": true,
            "mac_catalyst_app": false,
            "ios_app_on_visionos": false,
            "free_memory": 123_456,
            "usable_memory": 654_321,
            "low_power_mode": true,
            "locale": "en_US",
            "orientation": "portrait",
            "battery_level": 42,
            "charging": true,
            "thermal_state": "nominal",
            "connection_type": "wifi"
        ], key: "device")
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.context?["device"] as NSDictionary?, [
                "arch": "arm64e",
                "family": "iOS",
                "model": "iPhone17,1",
                "model_id": "D93AP",
                "simulator": false,
                "memory_size": 8_000_000_000,
                "screen_height_pixels": 2_622,
                "screen_width_pixels": 1_206,
                "ios_app_on_macos": true,
                "mac_catalyst_app": false,
                "ios_app_on_visionos": false
            ])
        }
    }

    func testDidReceive_whenDiagnosticFromPreviousProcessAndScopeHasRuntimeContext_shouldKeepRuntimeContext() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        let runtimeContext = ["name": "iOS App on Mac", "raw_description": "ios-app-on-mac"]
        SentrySDKInternal.currentHub().scope.setContext(value: runtimeContext, key: "runtime")
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.context?["runtime"] as? [String: String], runtimeContext)
        }
    }

    func testDidReceive_whenDiagnosticFromPreviousProcess_shouldNotCopyOtherScopeContexts() throws {
        // -- Arrange --
        givenSDKWithHubWithScope()
        SentrySDKInternal.currentHub().scope.setContext(value: ["key": "value"], key: "custom")
        let sut = givenSut(releaseName: "io.sentry.app@2.0.0+20")
        let payload = try givenHangPayload(appVersion: "2.0.0", appBuild: "20")

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNil(event?.context?["custom"])
            XCTAssertNil(event?.context?["culture"])
        }
    }

    // MARK: - Stable device context keys

    /// Guards the stable device context keys against new keys in the scope context enricher: a
    /// key the enricher adds has to be classified as stable or mutable, or this test fails.
    func testDiagnosticDeviceContext_whenScopeIsEnriched_shouldDropOnlyMutableKeys() throws {
        // -- Arrange --
        let processInfo = MockSentryProcessInfo()
        processInfo.overrides.isiOSAppOnMac = true
        processInfo.overrides.isMacCatalystApp = true
        processInfo.overrides.isiOSAppOnVisionOS = true
        let enricher = SentryDefaultScopeContextEnricher(
            processInfoWrapper: processInfo,
            systemInfoProvider: TestSystemInfoProvider(value: SentrySystemInfo(
                systemName: "iOS",
                osBuild: "23A340",
                kernelVersion: "Darwin Kernel Version 25.0.0",
                isJailbroken: false,
                cpuArchitecture: "arm64e",
                machine: "iPhone17,1",
                model: "D93AP",
                freeMemorySize: 123_456,
                usableMemorySize: 654_321,
                memorySize: 8_000_000_000,
                appStartTime: "2026-10-05T10:00:00.000Z",
                deviceAppHash: "abc123",
                appID: nil,
                buildType: "app store"
            )),
            bundleInfo: ["CFBundleIdentifier": "io.sentry.app"],
            osVersionProvider: { "26.0" },
            screenSizeProvider: { CGSize(width: 1_206, height: 2_622) }
        )
        let scope = Scope()
        enricher.enrichScope(scope)
        let runningDevice = try XCTUnwrap(scope.getContextForKey("device"))

        // -- Act --
        let deviceContext = try XCTUnwrap(SentryMXManager.diagnosticDeviceContext(runningDevice: runningDevice))

        // -- Assert --
        var mutableKeys: Set<String> = ["free_memory", "usable_memory"]
#if !SDK_V10
        mutableKeys.insert("locale")
#endif
        XCTAssertEqual(
            Set(runningDevice.keys).subtracting(deviceContext.keys),
            mutableKeys,
            "The enricher sets a device key that is neither in SentryMXManager.stableDeviceContextKeys nor in the mutable keys of this test. Decide whether it can change between app runs on the same device, then add it to one of them."
        )
    }

    private static let currentPid: pid_t = 4_242
    private static let previousProcessPid: pid_t = 1_337
    private static let processStartDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func requirePidSupport() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else {
            throw XCTSkip("MXMetaData.pid requires iOS 17 or macOS 14")
        }
    }

    private func givenSut(releaseName: String?) -> SentryMXManager {
        SentryMXManager(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            attachDiagnosticAsAttachment: false,
            enabledDiagnostics: [.hang],
            releaseName: releaseName,
            bundleInfo: [
                "CFBundleIdentifier": "io.sentry.app",
                "CFBundleShortVersionString": "2.0.0",
                "CFBundleVersion": "20"
            ],
            processIdentifier: Self.currentPid,
            processStartDate: Self.processStartDate
        )
    }

    /// Builds a hang payload that, by default, was recorded by a previous process of the app: its
    /// process differs from the running one and its window opened before the process started.
    private func givenHangPayload(
        appVersion: String,
        appBuild: String,
        osVersion: String = "iPhone OS 18.6.2 (22G100)",
        pid: pid_t = SentryMXManagerMetadataTests.previousProcessPid,
        timeStampBegin: Date = SentryMXManagerMetadataTests.processStartDate.addingTimeInterval(-3_600)
    ) throws -> TestMXDiagnosticPayload {
        let metaData = TestMXMetaData()
        metaData.overrides.applicationBuildVersion = appBuild
        metaData.overrides.osVersion = osVersion
        metaData.overrides.pid = pid

        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
        diagnostic.overrides.metaData = metaData
        diagnostic.overrides.applicationVersion = appVersion

        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]
        payload.overrides.timeStampBegin = timeStampBegin
        return payload
    }

    private static let runningAppContext: [String: Any] = [
        "app_identifier": "io.sentry.app",
        "app_name": "SentryApp",
        "app_version": "2.0.0",
        "app_build": "20",
        "build_type": "app store",
        "app_start_time": "2026-10-05T10:00:00.000Z",
        "device_app_hash": "abc123"
    ]

    private static let runningOSContext: [String: Any] = [
        "name": "iOS",
        "version": "26.0",
        "build": "23A340",
        "kernel_version": "Darwin Kernel Version 25.0.0",
        "rooted": false
    ]

    private func givenSDKWithHubWithScope(appContext: [String: Any]? = nil, osContext: [String: Any]? = nil) {
        let scope = Scope()
        scope.addBreadcrumb(TestData.crumb)
        scope.addAttachment(TestData.dataAttachment)

        givenSdkWithHub(scope: scope)

        // Creating the hub enriches the scope with the running app and OS, so presets must come after.
        if let appContext {
            SentrySDKInternal.currentHub().scope.setContext(value: appContext, key: "app")
        }
        if let osContext {
            SentrySDKInternal.currentHub().scope.setContext(value: osContext, key: "os")
        }
    }
}

private final class TestSystemInfoProvider: SentrySystemInfoProvider {
    private let value: SentrySystemInfo

    init(value: SentrySystemInfo) {
        self.value = value
    }

    func systemInfo() -> SentrySystemInfo {
        value
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
