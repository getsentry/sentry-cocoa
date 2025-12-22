@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class BatcherScopeTests: XCTestCase {
    private struct TestItem: BatcherItem, Encodable {
        var attributesMap: [String: SentryAttributeValue]
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
            try container.encode(attributesMap, forKey: .attributes)
        }
    }

    private struct TestConfig: BatcherConfig {
        typealias Item = TestItem

        let sendDefaultPii: Bool

        let flushTimeout: TimeInterval
        let maxItemCount: Int
        let maxBufferSizeBytes: Int

        let beforeSendItem: ((TestItem) -> TestItem?)?

        var capturedDataCallback: (Data, Int) -> Void
    }

    private struct TestMetadata: BatcherMetadata {
        let environment: String
        let releaseName: String?
        let installationId: String?
    }

    private struct TestScope: BatcherScope {
        var replayId: String?
        var propagationContextTraceIdString: String
        var span: Span?
        var userObject: User?
        var contextStore: [String: [String: Any]] = [:]
        var attributes: [String: Any] = [:]
        var sendDefaultPii = true

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
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["sentry.sdk.name"], .string(SentryMeta.sdkName))
    }

    func testApplyToItem_shouldAddSDKVersion() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["sentry.sdk.version"], .string(SentryMeta.versionString))
    }

    func testApplyToItem_shouldAddEnvironment() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata(environment: "test-environment")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["sentry.environment"], .string("test-environment"))
    }

    func testApplyToItem_withReleaseName_shouldAddRelease() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata(releaseName: "test-release-1.0.0")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["sentry.release"], .string("test-release-1.0.0"))
    }

    func testApplyToItem_withoutReleaseName_shouldNotAddRelease() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata(releaseName: nil)
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["sentry.release"])
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
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["span_id"], .string(span.spanId.sentrySpanIdString))
    }

    func testApplyToItem_withoutSpan_shouldNotAddParentSpanId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["sentry.trace.parent_span_id"])
    }

    // MARK: - OS Attributes Tests

    func testApplyToItem_withOSContext_shouldAddOSName() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["name": "iOS", "version": "17.0"], key: "os")
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["os.name"], .string("iOS"))
    }

    func testApplyToItem_withOSContext_shouldAddOSVersion() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["name": "iOS", "version": "17.0"], key: "os")
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["os.version"], .string("17.0"))
    }

    func testApplyToItem_withOSContextWithoutName_shouldNotAddOSName() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["version": "17.0"], key: "os")
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["os.name"])
    }

    func testApplyToItem_withOSContextWithoutVersion_shouldNotAddOSVersion() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["name": "iOS"], key: "os")
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["os.version"])
    }

    func testApplyToItem_withoutOSContext_shouldNotAddOSAttributes() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["os.name"])
        XCTAssertNil(item.attributesMap["os.version"])
    }

    // MARK: - Device Attributes Tests

    func testApplyToItem_withDeviceContext_shouldAddDeviceBrand() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["model": "iPhone15,2"], key: "device")
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["device.brand"], .string("Apple"))
    }

    func testApplyToItem_withDeviceContext_shouldAddDeviceModel() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["model": "iPhone15,2"], key: "device")
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["device.model"], .string("iPhone15,2"))
    }

    func testApplyToItem_withDeviceContext_shouldAddDeviceFamily() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["family": "iPhone"], key: "device")
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["device.family"], .string("iPhone"))
    }

    func testApplyToItem_withDeviceContextWithoutModel_shouldNotAddDeviceModel() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["family": "iPhone"], key: "device")
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["device.model"])
    }

    func testApplyToItem_withDeviceContextWithoutFamily_shouldNotAddDeviceFamily() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.setContext(value: ["model": "iPhone15,2"], key: "device")
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["device.family"])
    }

    func testApplyToItem_withoutDeviceContext_shouldNotAddDeviceAttributes() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["device.brand"])
        XCTAssertNil(item.attributesMap["device.model"])
        XCTAssertNil(item.attributesMap["device.family"])
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
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["user.id"], .string("user-123"))
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
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["user.name"], .string("John Doe"))
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
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["user.email"], .string("john@example.com"))
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
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["user.id"], .string("user-123"))
        XCTAssertEqual(item.attributesMap["user.name"], .string("John Doe"))
        XCTAssertEqual(item.attributesMap["user.email"], .string("john@example.com"))
    }

    func testApplyToItem_withoutUser_shouldNotAddUserAttributes() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata(installationId: nil)
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["user.id"])
        XCTAssertNil(item.attributesMap["user.name"])
        XCTAssertNil(item.attributesMap["user.email"])
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
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["sentry.replay_id"], .string("replay-123"))
    }

    func testApplyToItem_withoutReplayId_shouldNotAddReplayId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["sentry.replay_id"])
    }
#endif
#endif

    // MARK: - Scope Attributes Tests

    func testApplyToItem_withScopeAttributes_shouldAddScopeAttributes() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.attributes = ["custom.key": "custom.value", "custom.number": 42, "custom.bool": true]
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["custom.key"], .string("custom.value"))
        XCTAssertEqual(item.attributesMap["custom.number"], .integer(42))
        XCTAssertEqual(item.attributesMap["custom.bool"], .boolean(true))
    }

    func testApplyToItem_withScopeAttributes_whenItemHasExistingAttribute_shouldNotOverride() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        scope.attributes = ["custom.key": "scope.value"]
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()
        item.attributesMap["custom.key"] = .string("item.value")

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        // Scope attributes should not override existing item attributes
        XCTAssertEqual(item.attributesMap["custom.key"], .string("item.value"))
    }

    // MARK: - Default User ID Tests

    func testApplyToItem_withoutUserAndWithInstallationId_shouldAddInstallationIdAsUserId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["user.id"], .string("installation-123"))
    }

    func testApplyToItem_withoutUserAndWithoutInstallationId_shouldNotAddUserId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceIdString: SentryId().sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata(installationId: nil)
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["user.id"])
    }

    func testApplyToItem_withUser_shouldNotAddInstallationIdAsUserId() {
        // -- Arrange --
        let user = User(userId: "user-123")
        let scope = TestScope(
            propagationContextTraceIdString: SentryId().sentryIdString,
            userObject: user
        )
        let config = createTestConfig()
        let metadata = createTestMetadata(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesMap["user.id"], .string("user-123"))
        XCTAssertNotEqual(item.attributesMap["user.id"], .string("installation-123"))
    }

    func testApplyToItem_withUserName_shouldNotAddInstallationIdAsUserId() {
        // -- Arrange --
        let user = User()
        user.name = "John Doe"
        let scope = TestScope(
            propagationContextTraceIdString: SentryId().sentryIdString,
            userObject: user
        )
        let config = createTestConfig()
        let metadata = createTestMetadata(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["user.id"])
    }

    func testApplyToItem_withUserEmail_shouldNotAddInstallationIdAsUserId() {
        // -- Arrange --
        let user = User()
        user.email = "john@example.com"
        let scope = TestScope(
            propagationContextTraceIdString: SentryId().sentryIdString,
            userObject: user
        )
        let config = createTestConfig()
        let metadata = createTestMetadata(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesMap["user.id"])
    }

    // MARK: - Trace ID Tests

    func testApplyToItem_shouldSetTraceId() {
        // -- Arrange --
        let traceId = SentryId()
        let scope = TestScope(propagationContextTraceIdString: traceId.sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.traceId, traceId)
    }

    func testApplyToItem_shouldSetTraceIdFromPropagationContext() {
        // -- Arrange --
        let traceId1 = SentryId()
        let traceId2 = SentryId()
        let scope = TestScope(propagationContextTraceIdString: traceId1.sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata()
        var item = createTestItem()
        item.traceId = traceId2

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

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

        let config = createTestConfig()
        let metadata = createTestMetadata(environment: "production", releaseName: "1.0.0", installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        // Default attributes
        XCTAssertEqual(item.attributesMap["sentry.sdk.name"], .string(SentryMeta.sdkName))
        XCTAssertEqual(item.attributesMap["sentry.sdk.version"], .string(SentryMeta.versionString))
        XCTAssertEqual(item.attributesMap["sentry.environment"], .string("production"))
        XCTAssertEqual(item.attributesMap["sentry.release"], .string("1.0.0"))
        XCTAssertEqual(item.attributesMap["span_id"], .string(span.spanId.sentrySpanIdString))

        // OS attributes
        XCTAssertEqual(item.attributesMap["os.name"], .string("iOS"))
        XCTAssertEqual(item.attributesMap["os.version"], .string("17.0"))

        // Device attributes
        XCTAssertEqual(item.attributesMap["device.brand"], .string("Apple"))
        XCTAssertEqual(item.attributesMap["device.model"], .string("iPhone15,2"))
        XCTAssertEqual(item.attributesMap["device.family"], .string("iPhone"))

        // User attributes
        XCTAssertEqual(item.attributesMap["user.id"], .string("user-123"))
        XCTAssertEqual(item.attributesMap["user.name"], .string("John Doe"))
        XCTAssertEqual(item.attributesMap["user.email"], .string("john@example.com"))

        // Trace ID
        XCTAssertEqual(item.traceId, traceId)
    }

    func testApplyToItem_withMinimalAttributes_shouldAddOnlyRequiredAttributes() {
        // -- Arrange --
        let traceId = SentryId()
        let scope = TestScope(propagationContextTraceIdString: traceId.sentryIdString)
        let config = createTestConfig()
        let metadata = createTestMetadata(environment: "test", releaseName: nil, installationId: nil)
        var item = createTestItem()

        // -- Act --
        scope.applyToItem(&item, config: config, metadata: metadata)

        // -- Assert --
        // Should always have these
        XCTAssertEqual(item.attributesMap["sentry.sdk.name"], .string(SentryMeta.sdkName))
        XCTAssertEqual(item.attributesMap["sentry.sdk.version"], .string(SentryMeta.versionString))
        XCTAssertEqual(item.attributesMap["sentry.environment"], .string("test"))
        XCTAssertEqual(item.traceId, traceId)

        // Should not have these
        XCTAssertNil(item.attributesMap["sentry.release"])
        XCTAssertNil(item.attributesMap["sentry.trace.parent_span_id"])
        XCTAssertNil(item.attributesMap["os.name"])
        XCTAssertNil(item.attributesMap["device.brand"])
        XCTAssertNil(item.attributesMap["user.id"])
    }

    // MARK: - Helpers

    private func createTestItem() -> TestItem {
        return TestItem(
            attributesMap: [:],
            traceId: SentryId(),
            body: "test body"
        )
    }

    private func createTestConfig() -> TestConfig {
        return TestConfig(
            sendDefaultPii: true,
            flushTimeout: 0.1,
            maxItemCount: 10,
            maxBufferSizeBytes: 8_000,
            beforeSendItem: nil,
            capturedDataCallback: { _, _ in }
        )
    }

    private func createTestMetadata(
        environment: String = "test-environment",
        releaseName: String? = "test-release",
        installationId: String? = "test-installation-id"
    ) -> TestMetadata {
        return TestMetadata(
            environment: environment,
            releaseName: releaseName,
            installationId: installationId
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
