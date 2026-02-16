@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class TelemetryScopeApplierTests: XCTestCase {
    private struct TestItem: TelemetryItem, Encodable {
        var attributes: [String: SentryAttribute]
        var attributesDict: [String: SentryAttributeContent]
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
            try container.encode(attributesDict, forKey: .attributes)
        }
    }

    private struct TestMetadata: TelemetryScopeMetadata {
        let environment: String
        let releaseName: String?
        let installationId: String?
        let sendDefaultPii: Bool
    }

    private struct TestScope: TelemetryScopeApplier {
        var replayId: String?
        var propagationContextTraceId: SentryId
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
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["sentry.sdk.name"], .string(SentryMeta.sdkName))
    }

    func testApplyToItem_shouldAddSDKVersion() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["sentry.sdk.version"], .string(SentryMeta.versionString))
    }

    func testApplyToItem_shouldAddEnvironment() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata(environment: "test-environment")
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["sentry.environment"], .string("test-environment"))
    }

    func testApplyToItem_withReleaseName_shouldAddRelease() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata(releaseName: "test-release-1.0.0")
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["sentry.release"], .string("test-release-1.0.0"))
    }

    func testApplyToItem_withoutReleaseName_shouldNotAddRelease() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata(releaseName: nil)
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["sentry.release"])
    }

    func testApplyToItem_withSpan_shouldAddParentSpanId() {
        // -- Arrange --
        let spanId = SentryId()
        let span = TestSpan(spanId: spanId)
        let scope = TestScope(
            propagationContextTraceId: SentryId(),
            span: span
        )
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["span_id"], .string(span.spanId.sentrySpanIdString))
    }

    func testApplyToItem_withoutSpan_shouldNotAddParentSpanId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["sentry.trace.parent_span_id"])
    }

    // MARK: - OS Attributes Tests

    func testApplyToItem_withOSContext_shouldAddOSName() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceId: SentryId())
        scope.setContext(value: ["name": "iOS", "version": "17.0"], key: "os")
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["os.name"], .string("iOS"))
    }

    func testApplyToItem_withOSContext_shouldAddOSVersion() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceId: SentryId())
        scope.setContext(value: ["name": "iOS", "version": "17.0"], key: "os")
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["os.version"], .string("17.0"))
    }

    func testApplyToItem_withOSContextWithoutName_shouldNotAddOSName() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceId: SentryId())
        scope.setContext(value: ["version": "17.0"], key: "os")
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["os.name"])
    }

    func testApplyToItem_withOSContextWithoutVersion_shouldNotAddOSVersion() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceId: SentryId())
        scope.setContext(value: ["name": "iOS"], key: "os")
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["os.version"])
    }

    func testApplyToItem_withoutOSContext_shouldNotAddOSAttributes() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["os.name"])
        XCTAssertNil(item.attributesDict["os.version"])
    }

    // MARK: - Device Attributes Tests

    func testApplyToItem_withDeviceContext_shouldAddDeviceBrand() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceId: SentryId())
        scope.setContext(value: ["model": "iPhone15,2"], key: "device")
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["device.brand"], .string("Apple"))
    }

    func testApplyToItem_withDeviceContext_shouldAddDeviceModel() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceId: SentryId())
        scope.setContext(value: ["model": "iPhone15,2"], key: "device")
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["device.model"], .string("iPhone15,2"))
    }

    func testApplyToItem_withDeviceContext_shouldAddDeviceFamily() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceId: SentryId())
        scope.setContext(value: ["family": "iPhone"], key: "device")
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["device.family"], .string("iPhone"))
    }

    func testApplyToItem_withDeviceContextWithoutModel_shouldNotAddDeviceModel() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceId: SentryId())
        scope.setContext(value: ["family": "iPhone"], key: "device")
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["device.model"])
        XCTAssertEqual(item.attributesDict["device.brand"], .string("Apple"))
    }

    func testApplyToItem_withDeviceContextWithoutFamily_shouldNotAddDeviceFamily() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceId: SentryId())
        scope.setContext(value: ["model": "iPhone15,2"], key: "device")
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["device.family"])
        XCTAssertEqual(item.attributesDict["device.brand"], .string("Apple"))
    }

    func testApplyToItem_withoutDeviceContext_shouldNotAddDeviceAttributes() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["device.brand"])
        XCTAssertNil(item.attributesDict["device.model"])
        XCTAssertNil(item.attributesDict["device.family"])
    }

    // MARK: - User Attributes Tests

    func testApplyToItem_withUser_shouldAddUserId() {
        // -- Arrange --
        let user = User(userId: "user-123")
        let scope = TestScope(
            propagationContextTraceId: SentryId(),
            userObject: user
        )
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["user.id"], .string("user-123"))
    }

    func testApplyToItem_withUser_shouldAddUserName() {
        // -- Arrange --
        let user = User()
        user.name = "John Doe"
        let scope = TestScope(
            propagationContextTraceId: SentryId(),
            userObject: user
        )
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["user.name"], .string("John Doe"))
    }

    func testApplyToItem_withUser_shouldAddUserEmail() {
        // -- Arrange --
        let user = User()
        user.email = "john@example.com"
        let scope = TestScope(
            propagationContextTraceId: SentryId(),
            userObject: user
        )
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["user.email"], .string("john@example.com"))
    }

    func testApplyToItem_withUserWithAllFields_shouldAddAllUserAttributes() {
        // -- Arrange --
        let user = User(userId: "user-123")
        user.name = "John Doe"
        user.email = "john@example.com"
        let scope = TestScope(
            propagationContextTraceId: SentryId(),
            userObject: user
        )
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["user.id"], .string("user-123"))
        XCTAssertEqual(item.attributesDict["user.name"], .string("John Doe"))
        XCTAssertEqual(item.attributesDict["user.email"], .string("john@example.com"))
    }

    func testApplyToItem_withoutUser_shouldNotAddUserAttributes() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata(installationId: nil)
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["user.id"])
        XCTAssertNil(item.attributesDict["user.name"])
        XCTAssertNil(item.attributesDict["user.email"])
    }

    func testApplyToItem_whenSendDefaultPiiFalse_shouldStillAddUserAttributes() {
        // -- Arrange --
        let user = User(userId: "user-123")
        user.name = "John Doe"
        user.email = "john@example.com"
        let scope = TestScope(
            propagationContextTraceId: SentryId(),
            userObject: user
        )
        let metadata = createTestMetadata(
            installationId: "installation-123",
            sendDefaultPii: false
        )
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        // User attributes are applied regardless of sendDefaultPII
        XCTAssertEqual(item.attributesDict["user.id"], .string("user-123"))
        XCTAssertEqual(item.attributesDict["user.name"], .string("John Doe"))
        XCTAssertEqual(item.attributesDict["user.email"], .string("john@example.com"))
    }

    // MARK: - Replay Attributes Tests

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)
    func testApplyToItem_withReplayId_shouldAddReplayId() {
        // -- Arrange --
        let scope = TestScope(
            replayId: "replay-123",
            propagationContextTraceId: SentryId()
        )
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["sentry.replay_id"], .string("replay-123"))
    }

    func testApplyToItem_withoutReplayId_shouldNotAddReplayId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["sentry.replay_id"])
    }
#endif
#endif

    // MARK: - Scope Attributes Tests

    func testApplyToItem_withScopeAttributes_shouldAddScopeAttributes() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceId: SentryId())
        scope.attributes = ["custom.key": "custom.value", "custom.number": 42, "custom.bool": true]
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["custom.key"], .string("custom.value"))
        XCTAssertEqual(item.attributesDict["custom.number"], .integer(42))
        XCTAssertEqual(item.attributesDict["custom.bool"], .boolean(true))
    }

    func testApplyToItem_withScopeAttributes_whenItemHasExistingAttribute_shouldNotOverride() {
        // -- Arrange --
        var scope = TestScope(propagationContextTraceId: SentryId())
        scope.attributes = ["custom.key": "scope.value"]
        let metadata = createTestMetadata()
        var item = createTestItem()
        item.attributesDict["custom.key"] = .string("item.value")

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        // Scope attributes should not override existing item attributes
        XCTAssertEqual(item.attributesDict["custom.key"], .string("item.value"))
    }

    // MARK: - Default User ID Tests

    func testApplyToItem_withoutUserAndWithInstallationId_shouldAddInstallationIdAsUserId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["user.id"], .string("installation-123"))
    }

    func testApplyToItem_withoutUserAndWithoutInstallationId_shouldNotAddUserId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata(installationId: nil)
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["user.id"])
    }

    func testApplyToItem_whenSendDefaultPiiFalse_withoutUser_shouldStillAddInstallationIdAsUserId() {
        // -- Arrange --
        let scope = TestScope(propagationContextTraceId: SentryId())
        let metadata = createTestMetadata(
            installationId: "installation-456",
            sendDefaultPii: false
        )
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["user.id"], .string("installation-456"))
        XCTAssertNil(item.attributesDict["user.name"])
        XCTAssertNil(item.attributesDict["user.email"])
    }

    func testApplyToItem_withUser_shouldNotAddInstallationIdAsUserId() {
        // -- Arrange --
        let user = User(userId: "user-123")
        let scope = TestScope(
            propagationContextTraceId: SentryId(),
            userObject: user
        )
        let metadata = createTestMetadata(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.attributesDict["user.id"], .string("user-123"))
        XCTAssertNotEqual(item.attributesDict["user.id"], .string("installation-123"))
    }

    func testApplyToItem_withUserName_shouldNotAddInstallationIdAsUserId() {
        // -- Arrange --
        let user = User()
        user.name = "John Doe"
        let scope = TestScope(
            propagationContextTraceId: SentryId(),
            userObject: user
        )
        let metadata = createTestMetadata(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["user.id"])
    }

    func testApplyToItem_withUserEmail_shouldNotAddInstallationIdAsUserId() {
        // -- Arrange --
        let user = User()
        user.email = "john@example.com"
        let scope = TestScope(
            propagationContextTraceId: SentryId(),
            userObject: user
        )
        let metadata = createTestMetadata(installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertNil(item.attributesDict["user.id"])
    }

    // MARK: - Trace ID Tests

    func testApplyToItem_shouldSetTraceId() {
        // -- Arrange --
        let traceId = SentryId()
        let scope = TestScope(propagationContextTraceId: traceId)
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.traceId, traceId)
    }

    func testApplyToItem_shouldSetTraceIdFromPropagationContext() {
        // -- Arrange --
        let traceId1 = SentryId()
        let traceId2 = SentryId()
        let scope = TestScope(propagationContextTraceId: traceId1)
        let metadata = createTestMetadata()
        var item = createTestItem()
        item.traceId = traceId2

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        XCTAssertEqual(item.traceId, traceId1)
    }

    func testApplyToItem_whenSpanIsActive_shouldSetTraceIdFromSpan() {
        // -- Arrange --
        let propagationTraceId = SentryId()
        let spanTraceId = SentryId()
        let spanId = SentryId()
        let span = TestSpan(spanId: spanId)
        span.traceId = spanTraceId
        
        let scope = TestScope(
            propagationContextTraceId: propagationTraceId,
            span: span
        )
        let metadata = createTestMetadata()
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        // When a span is active, traceId should come from the span, not propagationContext
        // This ensures consistency with span_id which also comes from the span
        XCTAssertEqual(item.traceId, spanTraceId)
        XCTAssertNotEqual(item.traceId, propagationTraceId)
        XCTAssertEqual(item.attributesDict["span_id"], .string(span.spanId.sentrySpanIdString))
    }

    func testApplyToItem_whenSpanIsActive_shouldUseSpanTraceIdEvenIfDifferentFromPropagationContext() {
        // -- Arrange --
        let propagationTraceId = SentryId()
        let spanTraceId = SentryId()
        // Ensure they are different
        XCTAssertNotEqual(propagationTraceId, spanTraceId)
        
        let spanId = SentryId()
        let span = TestSpan(spanId: spanId)
        span.traceId = spanTraceId
        
        let scope = TestScope(
            propagationContextTraceId: propagationTraceId,
            span: span
        )
        let metadata = createTestMetadata()
        var item = createTestItem()
        // Set initial traceId to something else to verify it gets overwritten
        item.traceId = SentryId()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        // traceId should be from span, ensuring correlation with span_id
        XCTAssertEqual(item.traceId, spanTraceId)
        XCTAssertNotEqual(item.traceId, propagationTraceId)
    }

    // MARK: - Integration Tests

    func testApplyToItem_withAllAttributes_shouldAddAllAttributes() {
        // -- Arrange --
        let traceId = SentryId()
        let spanId = SentryId()
        let span = TestSpan(spanId: spanId)
        // Set span traceId to match propagationContext traceId for consistency
        span.traceId = traceId
        let user = User(userId: "user-123")
        user.name = "John Doe"
        user.email = "john@example.com"

        var scope = TestScope(
            propagationContextTraceId: traceId,
            span: span,
            userObject: user
        )
        scope.setContext(value: ["name": "iOS", "version": "17.0"], key: "os")
        scope.setContext(value: ["model": "iPhone15,2", "family": "iPhone"], key: "device")

        let metadata = createTestMetadata(environment: "production", releaseName: "1.0.0", installationId: "installation-123")
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        // Default attributes
        XCTAssertEqual(item.attributesDict["sentry.sdk.name"], .string(SentryMeta.sdkName))
        XCTAssertEqual(item.attributesDict["sentry.sdk.version"], .string(SentryMeta.versionString))
        XCTAssertEqual(item.attributesDict["sentry.environment"], .string("production"))
        XCTAssertEqual(item.attributesDict["sentry.release"], .string("1.0.0"))
        XCTAssertEqual(item.attributesDict["span_id"], .string(span.spanId.sentrySpanIdString))

        // OS attributes
        XCTAssertEqual(item.attributesDict["os.name"], .string("iOS"))
        XCTAssertEqual(item.attributesDict["os.version"], .string("17.0"))

        // Device attributes
        XCTAssertEqual(item.attributesDict["device.brand"], .string("Apple"))
        XCTAssertEqual(item.attributesDict["device.model"], .string("iPhone15,2"))
        XCTAssertEqual(item.attributesDict["device.family"], .string("iPhone"))

        // User attributes
        XCTAssertEqual(item.attributesDict["user.id"], .string("user-123"))
        XCTAssertEqual(item.attributesDict["user.name"], .string("John Doe"))
        XCTAssertEqual(item.attributesDict["user.email"], .string("john@example.com"))

        // Trace ID
        XCTAssertEqual(item.traceId, traceId)
    }

    func testApplyToItem_withMinimalAttributes_shouldAddOnlyRequiredAttributes() {
        // -- Arrange --
        let traceId = SentryId()
        let scope = TestScope(propagationContextTraceId: traceId)
        let metadata = createTestMetadata(environment: "test", releaseName: nil, installationId: nil)
        var item = createTestItem()

        // -- Act --
        scope.addAttributesToItem(&item, metadata: metadata)

        // -- Assert --
        // Should always have these
        XCTAssertEqual(item.attributesDict["sentry.sdk.name"], .string(SentryMeta.sdkName))
        XCTAssertEqual(item.attributesDict["sentry.sdk.version"], .string(SentryMeta.versionString))
        XCTAssertEqual(item.attributesDict["sentry.environment"], .string("test"))
        XCTAssertEqual(item.traceId, traceId)

        // Should not have these
        XCTAssertNil(item.attributesDict["sentry.release"])
        XCTAssertNil(item.attributesDict["sentry.trace.parent_span_id"])
        XCTAssertNil(item.attributesDict["os.name"])
        XCTAssertNil(item.attributesDict["device.brand"])
        XCTAssertNil(item.attributesDict["user.id"])
    }

    // MARK: - Helpers

    private func createTestItem() -> TestItem {
        return TestItem(
            attributes: [:],
            attributesDict: [:],
            traceId: SentryId(),
            body: "test body"
        )
    }

    private func createTestMetadata(
        environment: String = "test-environment",
        releaseName: String? = "test-release",
        installationId: String? = "test-installation-id",
        sendDefaultPii: Bool = true
    ) -> TestMetadata {
        return TestMetadata(
            environment: environment,
            releaseName: releaseName,
            installationId: installationId,
            sendDefaultPii: sendDefaultPii
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
