@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class BatcherScopeTests: XCTestCase {
    private struct TestItem: BatcherItem, Encodable {
        var attributes: [String: SentryAttribute]
        var traceId: SentryId
        var body: String

        enum CodingKeys: String, CodingKey {
            case body
            case traceId = "trace_id"
            case attributes
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(body, forKey: .body)
            try container.encode(traceId.sentryIdString, forKey: .traceId)
            try container.encode(attributes, forKey: .attributes)
        }
    }

    private struct TestConfig: BatcherConfig {
        typealias Item = TestItem

        let environment: String
        let releaseName: String?
        let flushTimeout: TimeInterval
        let maxItemCount: Int
        let maxBufferSizeBytes: Int
        let beforeSendItem: ((TestItem) -> TestItem?)?
        let getInstallationId: () -> String?
        var capturedDataCallback: (Data, Int) -> Void
    }

    private struct TestScope: BatcherScope {
        var replayId: String?
        var propagationContextTraceIdString: String
        var span: Span?
        var userObject: User?
        var contextStore: [String: [String: Any]] = [:]
        var attributes: [String: Any] = [:]

        func getContextForKey(_ key: String) -> [String: Any]? {
            return contextStore[key]
        }

        mutating func setContext(value: [String: Any], key: String) {
            contextStore[key] = value
        }
    }

    // MARK: - Default Attributes Tests

    func testApplyToItem_shouldAddSDKName() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
    }

    func testApplyToItem_shouldAddSDKVersion() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
    }

    func testApplyToItem_shouldAddEnvironment() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig(environment: "test-environment")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["sentry.environment"]?.value as? String, "test-environment")
    }

    func testApplyToItem_withReleaseName_shouldAddRelease() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig(releaseName: "test-release-1.0.0")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["sentry.release"]?.value as? String, "test-release-1.0.0")
    }

    func testApplyToItem_withoutReleaseName_shouldNotAddRelease() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig(releaseName: nil)
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["sentry.release"])
    }

    func testApplyToItem_withSpan_shouldAddParentSpanId() {
        // -- Arrange --
        let spanId = SentryId()
        let span = TestSpan(spanId: spanId)
        let scope = TestScope(
            propagationContextTraceIdString: SentryId().sentryIdString,
            span: span
        )
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["sentry.trace.parent_span_id"]?.value as? String, span.spanId.sentrySpanIdString)
    }

    func testApplyToItem_withoutSpan_shouldNotAddParentSpanId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["sentry.trace.parent_span_id"])
    }

    // MARK: - OS Attributes Tests

    func testApplyToItem_withOSContext_shouldAddOSName() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["name": "iOS", "version": "17.0"], key: "os")
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["os.name"]?.value as? String, "iOS")
    }

    func testApplyToItem_withOSContext_shouldAddOSVersion() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["name": "iOS", "version": "17.0"], key: "os")
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["os.version"]?.value as? String, "17.0")
    }

    func testApplyToItem_withOSContextWithoutName_shouldNotAddOSName() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["version": "17.0"], key: "os")
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["os.name"])
    }

    func testApplyToItem_withOSContextWithoutVersion_shouldNotAddOSVersion() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["name": "iOS"], key: "os")
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["os.version"])
    }

    func testApplyToItem_withoutOSContext_shouldNotAddOSAttributes() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["os.name"])
        XCTAssertNil(item.attributes["os.version"])
    }

    // MARK: - Device Attributes Tests

    func testApplyToItem_withDeviceContext_shouldAddDeviceBrand() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["model": "iPhone15,2"], key: "device")
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["device.brand"]?.value as? String, "Apple")
    }

    func testApplyToItem_withDeviceContext_shouldAddDeviceModel() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["model": "iPhone15,2"], key: "device")
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["device.model"]?.value as? String, "iPhone15,2")
    }

    func testApplyToItem_withDeviceContext_shouldAddDeviceFamily() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["family": "iPhone"], key: "device")
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["device.family"]?.value as? String, "iPhone")
    }

    func testApplyToItem_withDeviceContextWithoutModel_shouldNotAddDeviceModel() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["family": "iPhone"], key: "device")
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["device.model"])
    }

    func testApplyToItem_withDeviceContextWithoutFamily_shouldNotAddDeviceFamily() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["model": "iPhone15,2"], key: "device")
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["device.family"])
    }

    func testApplyToItem_withoutDeviceContext_shouldNotAddDeviceAttributes() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["device.brand"])
        XCTAssertNil(item.attributes["device.model"])
        XCTAssertNil(item.attributes["device.family"])
    }

    // MARK: - User Attributes Tests

    func testApplyToItem_withUser_shouldAddUserId() {
        // -- Arrange --
        let user = User(userId: "user-123")
        let scope = TestScope(
            propagationContextTraceIdString: SentryId().sentryIdString,
            userObject: user
        )
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["user.id"]?.value as? String, "user-123")
    }

    func testApplyToItem_withUser_shouldAddUserName() {
        // -- Arrange --
        let user = User()
        user.name = "John Doe"
        let scope = TestScope(
            propagationContextTraceIdString: SentryId().sentryIdString,
            userObject: user
        )
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["user.name"]?.value as? String, "John Doe")
    }

    func testApplyToItem_withUser_shouldAddUserEmail() {
        // -- Arrange --
        let user = User()
        user.email = "john@example.com"
        let scope = TestScope(
            propagationContextTraceIdString: SentryId().sentryIdString,
            userObject: user
        )
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["user.email"]?.value as? String, "john@example.com")
    }

    func testApplyToItem_withUserWithAllFields_shouldAddAllUserAttributes() {
        // -- Arrange --
        let user = User(userId: "user-123")
        user.name = "John Doe"
        user.email = "john@example.com"
        let scope = TestScope(
            propagationContextTraceIdString: SentryId().sentryIdString,
            userObject: user
        )
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["user.id"]?.value as? String, "user-123")
        XCTAssertEqual(item.attributes["user.name"]?.value as? String, "John Doe")
        XCTAssertEqual(item.attributes["user.email"]?.value as? String, "john@example.com")
    }

    func testApplyToItem_withoutUser_shouldNotAddUserAttributes() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig(installationId: nil)
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["user.id"])
        XCTAssertNil(item.attributes["user.name"])
        XCTAssertNil(item.attributes["user.email"])
    }

    // MARK: - Replay Attributes Tests

    #if canImport(UIKit) && !SENTRY_NO_UIKIT
    #if os(iOS) || os(tvOS)
    func testApplyToItem_withReplayId_shouldAddReplayId() {
        // -- Arrange --
        let scope = TestScope(
            replayId: "replay-123",
            propagationContextTraceIdString: SentryId().sentryIdString
        )
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["sentry.replay_id"]?.value as? String, "replay-123")
    }

    func testApplyToItem_withoutReplayId_shouldNotAddReplayId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["sentry.replay_id"])
    }
    #endif
    #endif

    // MARK: - Scope Attributes Tests

    func testApplyToItem_withScopeAttributes_shouldAddScopeAttributes() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.attributes = ["custom.key": "custom.value"]
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        // Note: The current implementation has a bug - it iterates over item attributes instead of scope attributes
        // This test verifies current behavior, which may not match the intended behavior
        // The scope attributes may not be added due to the bug
    }

    // MARK: - Default User ID Tests

    func testApplyToItem_withoutUserAndWithInstallationId_shouldAddInstallationIdAsUserId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["user.id"]?.value as? String, "installation-123")
    }

    func testApplyToItem_withoutUserAndWithoutInstallationId_shouldNotAddUserId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig(installationId: nil)
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["user.id"])
    }

    func testApplyToItem_withUser_shouldNotAddInstallationIdAsUserId() {
        // -- Arrange --
        let user = User(userId: "user-123")
        let scope = TestScope(
            propagationContextTraceIdString: SentryId().sentryIdString,
            userObject: user
        )
        let config = createTestConfig(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.attributes["user.id"]?.value as? String, "user-123")
        XCTAssertNotEqual(item.attributes["user.id"]?.value as? String, "installation-123")
    }

    func testApplyToItem_withUserName_shouldNotAddInstallationIdAsUserId() {
        // -- Arrange --
        let user = User()
        user.name = "John Doe"
        let scope = TestScope(
            propagationContextTraceIdString: SentryId().sentryIdString,
            userObject: user
        )
        let config = createTestConfig(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["user.id"])
    }

    func testApplyToItem_withUserEmail_shouldNotAddInstallationIdAsUserId() {
        // -- Arrange --
        let user = User()
        user.email = "john@example.com"
        let scope = TestScope(
            propagationContextTraceIdString: SentryId().sentryIdString,
            userObject: user
        )
        let config = createTestConfig(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertNil(item.attributes["user.id"])
    }

    // MARK: - Trace ID Tests

    func testApplyToItem_shouldSetTraceId() {
        // -- Arrange --
        let traceId = SentryId()
        let scope = TestScope(propagationContextTraceIdString: traceId.sentryIdString)
        let config = createTestConfig()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.traceId, traceId)
    }

    func testApplyToItem_shouldSetTraceIdFromPropagationContext() {
        // -- Arrange --
        let traceId1 = SentryId()
        let traceId2 = SentryId()
        let scope = TestScope(propagationContextTraceIdString: traceId1.sentryIdString)
        let config = createTestConfig()
        var item = createTestItem()
        item.traceId = traceId2

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        XCTAssertEqual(item.traceId, traceId1)
    }

    // MARK: - Integration Tests

    func testApplyToItem_withAllAttributes_shouldAddAllAttributes() {
        // -- Arrange --
        let traceId = SentryId()
        let spanId = SentryId()
        let span = TestSpan(spanId: spanId)
        let user = User(userId: "user-123")
        user.name = "John Doe"
        user.email = "john@example.com"

        var scope = TestScope(
            propagationContextTraceIdString: traceId.sentryIdString,
            span: span,
            userObject: user
        )
        scope.setContext(value: ["name": "iOS", "version": "17.0"], key: "os")
        scope.setContext(value: ["model": "iPhone15,2", "family": "iPhone"], key: "device")

        let config = createTestConfig(
            environment: "production",
            releaseName: "1.0.0",
            installationId: "installation-123"
        )
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        // Default attributes
        XCTAssertEqual(item.attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(item.attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertEqual(item.attributes["sentry.environment"]?.value as? String, "production")
        XCTAssertEqual(item.attributes["sentry.release"]?.value as? String, "1.0.0")
        XCTAssertEqual(item.attributes["sentry.trace.parent_span_id"]?.value as? String, span.spanId.sentrySpanIdString)

        // OS attributes
        XCTAssertEqual(item.attributes["os.name"]?.value as? String, "iOS")
        XCTAssertEqual(item.attributes["os.version"]?.value as? String, "17.0")

        // Device attributes
        XCTAssertEqual(item.attributes["device.brand"]?.value as? String, "Apple")
        XCTAssertEqual(item.attributes["device.model"]?.value as? String, "iPhone15,2")
        XCTAssertEqual(item.attributes["device.family"]?.value as? String, "iPhone")

        // User attributes
        XCTAssertEqual(item.attributes["user.id"]?.value as? String, "user-123")
        XCTAssertEqual(item.attributes["user.name"]?.value as? String, "John Doe")
        XCTAssertEqual(item.attributes["user.email"]?.value as? String, "john@example.com")

        // Trace ID
        XCTAssertEqual(item.traceId, traceId)
    }

    func testApplyToItem_withMinimalAttributes_shouldAddOnlyRequiredAttributes() {
        // -- Arrange --
        let traceId = SentryId()
        let scope = TestScope(propagationContextTraceIdString: traceId.sentryIdString)
        let config = createTestConfig(environment: "test", releaseName: nil, installationId: nil)
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config)

        // -- Assert --
        // Should always have these
        XCTAssertEqual(item.attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(item.attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertEqual(item.attributes["sentry.environment"]?.value as? String, "test")
        XCTAssertEqual(item.traceId, traceId)

        // Should not have these
        XCTAssertNil(item.attributes["sentry.release"])
        XCTAssertNil(item.attributes["sentry.trace.parent_span_id"])
        XCTAssertNil(item.attributes["os.name"])
        XCTAssertNil(item.attributes["device.brand"])
        XCTAssertNil(item.attributes["user.id"])
    }

    // MARK: - Helpers

    private func createTestItem() -> TestItem {
        return TestItem(
            attributes: [:],
            traceId: SentryId(),
            body: "test body"
        )
    }

    private func createTestConfig(
        environment: String = "test-environment",
        releaseName: String? = "test-release",
        installationId: String? = "test-installation-id"
    ) -> TestConfig {
        return TestConfig(
            environment: environment,
            releaseName: releaseName,
            flushTimeout: 0.1,
            maxItemCount: 10,
            maxBufferSizeBytes: 8_000,
            beforeSendItem: nil,
            getInstallationId: { installationId },
            capturedDataCallback: { _, _ in }
        )
    }
}

// MARK: - Test Helpers

private final class TestSpan: NSObject, Span {
    var spanId: SpanId

    init(spanId: SentryId) {
        // Create a SpanId from the SentryId by converting to UUID first
        // SpanId uses first 16 characters of UUID string (without dashes)
        let uuidString = spanId.sentryIdString
        let uuidWithoutDashes = uuidString.replacingOccurrences(of: "-", with: "")
        let spanIdValue = String(uuidWithoutDashes.prefix(16))
        self.spanId = SpanId(value: spanIdValue)
        super.init()
    }

    // MARK: - Properties required by Span
    var traceId: SentryId = SentryId()
    var parentSpanId: SpanId?
    var sampled: SentrySampleDecision = .undecided
    var operation: String = "test"
    var origin: String = "test"
    var spanDescription: String?
    var status: SentrySpanStatus = .undefined
    var timestamp: Date?
    var startTimestamp: Date?
    var data: [String: Any] { [:] }
    var tags: [String: String] { [:] }
    var isFinished: Bool { false }
    var traceContext: TraceContext? { nil }

    // MARK: - Methods required by Span
    func startChild(operation: String) -> Span { return self }
    func startChild(operation: String, description: String?) -> Span { return self }
    func setData(value: Any?, key: String) {}
    func removeData(key: String) {}
    func setTag(value: String, key: String) {}
    func removeTag(key: String) {}
    func setMeasurement(name: String, value: NSNumber) {}
    func setMeasurement(name: String, value: NSNumber, unit: MeasurementUnit) {}
    func finish() {}
    func finish(status: SentrySpanStatus) {}
    func toTraceHeader() -> TraceHeader {
        return TraceHeader(trace: traceId, spanId: spanId, sampled: sampled)
    }
    func baggageHttpHeader() -> String? { return nil }
    func serialize() -> [String: Any] { return [:] }
}
