@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryHangTrackingV3IntegrationTests: XCTestCase {

    // MARK: - Test Helpers

    private var mockTracker: MockAppHangTracker!
    private var testClient: TestClient!

    override func setUp() {
        super.setUp()
        mockTracker = MockAppHangTracker()
        testClient = TestClient(options: Options())
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    private func makeSUT(
        enableV3: Bool = true,
        includeClient: Bool = true,
        extensionIdentifier: String? = nil,
        hub: Hub? = nil
    ) -> SentryHangTrackingV3Integration<MockIntegrationDependencies>? {
        let options = Options()
        options.experimental.appHangs.enableV3 = enableV3
        options.experimental.appHangs.threshold = 2.0

        let infoPlistWrapper = TestInfoPlistWrapper()
        if let extensionIdentifier {
            infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
                forKey: "NSExtension",
                value: ["NSExtensionPointIdentifier": extensionIdentifier]
            )
        } else {
            infoPlistWrapper.mockGetAppValueDictionaryThrowError(
                forKey: "NSExtension",
                error: SentryInfoPlistError.keyNotFound(key: "NSExtension")
            )
        }

        let deps = MockIntegrationDependencies(
            appHangTracker: mockTracker,
            client: includeClient ? testClient : nil,
            hub: hub ?? StubHub(),
            extensionDetector: SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)
        )
        return SentryHangTrackingV3Integration(with: options, dependencies: deps)
    }

    private func makeHang(state: SentryAppHang.State, duration: TimeInterval = 2.0) -> SentryAppHang {
        SentryAppHang(duration: duration, state: state)
    }

    // MARK: - Init Tests

    func testInit_whenEnableV3IsFalse_returnsNil() {
        let sut = makeSUT(enableV3: false)
        XCTAssertNil(sut)
    }

    func testInit_whenEnableV3IsTrue_succeeds() {
        let sut = makeSUT(enableV3: true)
        XCTAssertNotNil(sut)
    }

    func testInit_inDisabledExtension_returnsNil() {
        let sut = makeSUT(extensionIdentifier: "com.apple.widgetkit-extension")
        XCTAssertNil(sut)
    }

    func testInit_inNonDisabledExtension_succeeds() {
        let sut = makeSUT(extensionIdentifier: "com.apple.keyboard-service")
        XCTAssertNotNil(sut)
    }

    // MARK: - State Filter Tests

    func testHangStarted_doesNotCaptureEvent() {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .started))
        XCTAssertTrue(testClient.captureEventInvocations.isEmpty, "Expected no events on .started")
    }

    func testHangEnded_capturesEvent() {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        XCTAssertEqual(testClient.captureEventInvocations.count, 1)
    }

    // MARK: - Event Content Tests

    func testHangEnded_capturesEventWithWarningLevel() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        XCTAssertEqual(event.level, .warning)
    }

    func testHangEnded_capturesEventWithAppHangingExceptionType() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        XCTAssertEqual(event.exceptions?.first?.type, "App Hanging")
    }

    func testHangEnded_exceptionValueContainsDuration() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended, duration: 3.5))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        let exceptionValue = try XCTUnwrap(event.exceptions?.first?.value)
        XCTAssertTrue(exceptionValue.contains("3.5"), "Exception value should include duration, got: \(exceptionValue)")
    }

    func testHangEnded_capturesEventWithAppHangMechanism() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        let mechanism = try XCTUnwrap(event.exceptions?.first?.mechanism)
        XCTAssertEqual(mechanism.type, "AppHang")
        XCTAssertEqual(mechanism.handled, NSNumber(value: true))
        XCTAssertEqual(mechanism.synthetic, NSNumber(value: true))
    }

    func testHangEnded_capturesEventWithMainThread() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        let thread = try XCTUnwrap(event.threads?.first)
        XCTAssertEqual(thread.threadId, NSNumber(value: 0))
        XCTAssertEqual(thread.name, "main")
        XCTAssertEqual(thread.crashed, NSNumber(value: false))
        XCTAssertEqual(thread.current, NSNumber(value: true))
        XCTAssertEqual(thread.isMain, NSNumber(value: true))
    }

    // MARK: - No Client Tests

    func testHangEnded_withNoClient_doesNotCaptureAndDoesNotCrash() {
        let sut = makeSUT(includeClient: false)
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        XCTAssertTrue(testClient.captureEventInvocations.isEmpty)
    }

    // MARK: - Profiling Context Tests

    func testHangEnded_withProfilerId_setsProfileContextOnEvent() throws {
        let stubHub = SpyHub()
        let sut = makeSUT(hub: stubHub)
        _ = sut

        let profilerId = SentryId()
        let hang = SentryAppHang(
            duration: 2.0,
            state: .ended,
            profilerId: profilerId,
            profilingData: nil,
            startSystemTime: 1_000,
            endSystemTime: 2_000
        )
        mockTracker.simulateHang(hang)

        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        let profileContext = try XCTUnwrap(event.context?["profile"] as? [String: Any])
        XCTAssertEqual(profileContext["profiler_id"] as? String, profilerId.sentryIdString)
    }

    func testHangEnded_withoutProfilerId_doesNotSetProfileContext() throws {
        let sut = makeSUT()
        _ = sut

        let hang = SentryAppHang(duration: 2.0, state: .ended)
        mockTracker.simulateHang(hang)

        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        XCTAssertNil(event.context?["profile"])
    }

    func testHangEnded_withProfilingData_sendsProfileChunkEnvelope() throws {
        let stubHub = SpyHub()
        let sut = makeSUT(hub: stubHub)
        _ = sut

        let profilerId = SentryId()
        let profilingData = SentryAppHang.ProfilingData(
            frames: [
                .init(instructionAddress: "0x1234", function: "main", module: "App")
            ],
            stacks: [[0]],
            samples: [
                .init(timestamp: 1_724_777_211.503, stackIndex: 0, threadId: 123)
            ],
            threadMetadata: ["123": .init(name: "main", priority: 31)]
        )
        let hang = SentryAppHang(
            duration: 2.0,
            state: .ended,
            profilerId: profilerId,
            profilingData: profilingData,
            startSystemTime: 1_000,
            endSystemTime: 2_000
        )
        mockTracker.simulateHang(hang)

        XCTAssertEqual(stubHub.capturedEnvelopes.count, 1)
        let envelope = try XCTUnwrap(stubHub.capturedEnvelopes.first)
        XCTAssertEqual(envelope.items.count, 1)
        XCTAssertEqual(envelope.items.first?.header.type, SentryEnvelopeItemTypes.profileChunk)
    }

    func testHangEnded_withProfilerIdButNoData_doesNotSendEnvelope() throws {
        let stubHub = SpyHub()
        let sut = makeSUT(hub: stubHub)
        _ = sut

        let hang = SentryAppHang(
            duration: 2.0,
            state: .ended,
            profilerId: SentryId(),
            profilingData: nil,
            startSystemTime: 1_000,
            endSystemTime: 2_000
        )
        mockTracker.simulateHang(hang)

        XCTAssertTrue(stubHub.capturedEnvelopes.isEmpty)
    }

    func testProfileChunkEnvelope_containsExpectedPayload() throws {
        let stubHub = SpyHub()
        let sut = makeSUT(hub: stubHub)
        _ = sut

        let profilerId = SentryId()
        let profilingData = SentryAppHang.ProfilingData(
            frames: [
                .init(instructionAddress: "0xABCD", function: "doWork", module: "MyApp")
            ],
            stacks: [[0]],
            samples: [
                .init(timestamp: 1_724_777_215.123, stackIndex: 0, threadId: 42)
            ],
            threadMetadata: ["42": .init(name: "main", priority: 31)]
        )
        let hang = SentryAppHang(
            duration: 2.0,
            state: .ended,
            profilerId: profilerId,
            profilingData: profilingData,
            startSystemTime: 1_000,
            endSystemTime: 2_000
        )
        mockTracker.simulateHang(hang)

        let envelope = try XCTUnwrap(stubHub.capturedEnvelopes.first)
        let itemData = try XCTUnwrap(envelope.items.first?.data)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: itemData) as? [String: Any])

        XCTAssertEqual(payload["version"] as? String, "2")
        XCTAssertEqual(payload["profiler_id"] as? String, profilerId.sentryIdString)
        XCTAssertEqual(payload["platform"] as? String, "cocoa")
        XCTAssertNotNil(payload["chunk_id"])
        XCTAssertNotNil(payload["profile"])
    }

    // MARK: - ProfilingData Serialization Tests

    func testProfilingData_toDictionary_serializesFrames() throws {
        let data = SentryAppHang.ProfilingData(
            frames: [
                .init(instructionAddress: "0x1", function: "foo", module: "Bar",
                      package: "sentrytest", imageAddress: "0x100000", inApp: true),
                .init(instructionAddress: nil, function: nil, module: nil)
            ],
            stacks: [[0, 1]],
            samples: [.init(timestamp: 1_724_777_211.503, stackIndex: 0, threadId: 1)],
            threadMetadata: [:]
        )

        let dict = data.toDictionary()
        let profile = try XCTUnwrap(dict["profile"] as? [String: Any])
        let frames = try XCTUnwrap(profile["frames"] as? [[String: Any]])

        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0]["instruction_addr"] as? String, "0x1")
        XCTAssertEqual(frames[0]["function"] as? String, "foo")
        XCTAssertEqual(frames[0]["module"] as? String, "Bar")
        XCTAssertEqual(frames[0]["package"] as? String, "sentrytest")
        XCTAssertEqual(frames[0]["image_addr"] as? String, "0x100000")
        XCTAssertEqual(frames[0]["in_app"] as? Bool, true)
        XCTAssertTrue(frames[1].isEmpty)
    }

    func testProfilingData_toDictionary_serializesSamples() throws {
        let data = SentryAppHang.ProfilingData(
            frames: [.init(instructionAddress: "0x1", function: "f", module: "M")],
            stacks: [[0]],
            samples: [.init(timestamp: 1_724_777_213.000, stackIndex: 0, threadId: 99)],
            threadMetadata: [:]
        )

        let dict = data.toDictionary()
        let profile = try XCTUnwrap(dict["profile"] as? [String: Any])
        let samples = try XCTUnwrap(profile["samples"] as? [[String: Any]])

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0]["thread_id"] as? String, "99")
        XCTAssertEqual(samples[0]["stack_id"] as? NSNumber, NSNumber(value: 0))
        let timestamp = try XCTUnwrap((samples[0]["timestamp"] as? NSNumber)?.doubleValue)
        XCTAssertEqual(timestamp, 1_724_777_213.000, accuracy: 0.001)
    }

    // MARK: - Name Tests

    func testName_shouldReturnCorrectName() {
        XCTAssertEqual(
            SentryHangTrackingV3Integration<MockIntegrationDependencies>.name,
            "SentryHangTrackingV3Integration"
        )
    }
}

// MARK: - Mock Infrastructure

private class MockAppHangTracker: SentryAppHangTracker {
    private var observers = [UUID: (SentryAppHang) -> Void]()

    func addObserver(threshold: TimeInterval, handler: @escaping (SentryAppHang) -> Void) -> UUID {
        let token = UUID()
        observers[token] = handler
        return token
    }

    func removeObserver(token: UUID) {
        observers.removeValue(forKey: token)
    }

    func simulateHang(_ hang: SentryAppHang) {
        for handler in observers.values {
            handler(hang)
        }
    }
}

private struct StubHub: Hub {
    func configureScope(_ callback: @escaping (Scope) -> Void) {}
    func storeEnvelope(_ envelope: SentryEnvelope) {}
    func captureEnvelope(_ envelope: SentryEnvelope) {}
    func setTrace(_ traceId: SentryId, spanId: SpanId) {}
    var options: Options { Options() }
}

private class SpyHub: Hub {
    var capturedEnvelopes = [SentryEnvelope]()
    func configureScope(_ callback: @escaping (Scope) -> Void) {}
    func storeEnvelope(_ envelope: SentryEnvelope) {}
    func captureEnvelope(_ envelope: SentryEnvelope) {
        capturedEnvelopes.append(envelope)
    }
    func setTrace(_ traceId: SentryId, spanId: SpanId) {}
    var options: Options { Options() }
}

private struct MockIntegrationDependencies: SentryHangTrackingV3IntegrationDependencies {
    let appHangTracker: SentryAppHangTracker
    let client: SentryClientInternal?
    let hub: Hub
    var extensionDetector: SentryExtensionDetector
    var threadInspector: SentryThreadInspector { SentryThreadInspector(options: nil) }
    var debugImageProvider: SentryDebugImageProvider { SentryDebugImageProvider() }
}
