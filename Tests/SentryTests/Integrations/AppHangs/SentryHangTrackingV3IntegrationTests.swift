// Only gated for these platforms so we can use Combine
#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryHangTrackingV3IntegrationTests: XCTestCase {

    // MARK: - Test Helpers

    private var mockTracker: MockAppHangTracker!
    private var testClient: TestClient!
    private var mockHub: MockHub!

    override func setUp() {
        super.setUp()
        mockTracker = MockAppHangTracker()
        testClient = TestClient(options: Options())
        mockHub = MockHub()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    private enum ClientOverride {
        case useDefault
        case useNil
        case use(SentryClientInternal)
    }

    private func makeSUT(
        enableV3: Bool = true,
        client: ClientOverride = .useDefault
    ) -> SentryHangTrackingV3Integration<MockIntegrationDependencies>? {
        let options = Options()
        options.experimental.appHangs.enableV3 = enableV3
        options.experimental.appHangs.appHangThreshold = 2.0
        let resolvedClient: SentryClientInternal?
        switch client {
        case .useDefault: resolvedClient = testClient
        case .useNil: resolvedClient = nil
        case .use(let c): resolvedClient = c
        }
        let deps = MockIntegrationDependencies(
            appHangTracker: mockTracker,
            client: resolvedClient,
            hub: mockHub
        )
        return SentryHangTrackingV3Integration(with: options, dependencies: deps)
    }

    private func makeHang(
        state: SentryAppHang.State,
        duration: TimeInterval = 2.0,
        profilerId: SentryId? = nil,
        profilingData: SentryAppHang.ProfilingData? = nil
    ) -> SentryAppHang {
        SentryAppHang(
            duration: duration,
            state: state,
            profilerId: profilerId,
            profilingData: profilingData,
            startSystemTime: 0,
            endSystemTime: 1_000_000_000
        )
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

    // MARK: - State Filter Tests

    func testHangStarted_doesNotCaptureEvent() {
        let sut = makeSUT()
        _ = sut
        let hang = makeHang(state: .started, profilerId: SentryId())
        mockTracker.simulateHang(hang)
        XCTAssertTrue(testClient.captureEventInvocations.isEmpty, "Expected no events on .started")
    }

    func testHangEnded_capturesEvent() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        XCTAssertEqual(testClient.captureEventInvocations.count, 1)
    }

    // MARK: - Event Content Tests

    func testHangEnded_capturesEventWithCorrectLevel() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        XCTAssertEqual(event.level, .warning)
    }

    func testHangEnded_capturesEventWithCorrectExceptionType() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        XCTAssertEqual(event.exceptions?.first?.type, "MXHangDiagnostic")
    }

    func testHangEnded_capturesEventWithMainThread() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        let thread = try XCTUnwrap(event.threads?.first)
        XCTAssertEqual(thread.name, "main")
        XCTAssertEqual(thread.isMain, true)
    }

    func testHangEnded_exceptionValueContainsDuration() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended, duration: 3.5))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        let exceptionValue = try XCTUnwrap(event.exceptions?.first?.value)
        XCTAssertTrue(exceptionValue.contains("3.5"), "Exception value should include duration, got: \(exceptionValue)")
    }

    // MARK: - Profile Context Tests

    func testHangEnded_withoutProfilerId_capturesEventWithoutProfileContext() throws {
        let sut = makeSUT()
        _ = sut
        mockTracker.simulateHang(makeHang(state: .ended, profilerId: nil))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        XCTAssertNil(event.context?["profile"])
    }

    func testHangEnded_withProfilerId_setsProfileContext() throws {
        let sut = makeSUT()
        _ = sut
        let profilerId = SentryId()
        mockTracker.simulateHang(makeHang(state: .ended, profilerId: profilerId))
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        let profileContext = try XCTUnwrap(event.context?["profile"] as? [String: Any])
        XCTAssertEqual(profileContext["profiler_id"] as? String, profilerId.sentryIdString)
    }

    func testHangEnded_withProfileId_withoutProfilingData_doesNotSendEnvelope() throws {
        let sut = makeSUT()
        _ = sut
        let profilerId = SentryId()
        mockTracker.simulateHang(makeHang(state: .ended, profilerId: profilerId, profilingData: nil))
        // Profile context is set on event
        let event = try XCTUnwrap(testClient.captureEventInvocations.last)
        let profileContext = try XCTUnwrap(event.context?["profile"] as? [String: Any])
        XCTAssertNotNil(profileContext["profiler_id"])
        // No envelope should have been sent
        XCTAssertTrue(mockHub.capturedEnvelopes.isEmpty)
    }

    // MARK: - No Client Tests

    func testHangEnded_withNoClient_doesNotCaptureAndDoesNotCrash() {
        let sut = makeSUT(client: .useNil)
        _ = sut
        // Should not crash with no client
        mockTracker.simulateHang(makeHang(state: .ended))
        XCTAssertTrue(testClient.captureEventInvocations.isEmpty)
    }

    // MARK: - ProfilingData.toDictionary Tests

    func testProfilingData_toDictionary_serializesFrames() throws {
        let data = SentryAppHang.ProfilingData(
            frames: [.init(instructionAddress: "0x1234", function: "main", module: "App")],
            stacks: [[0]],
            samples: [.init(absoluteTimestamp: 1_000_000_000, stackIndex: 0, threadId: 259)],
            threadMetadata: ["259": .init(name: "main", priority: 0)]
        )
        let dict = data.toDictionary()
        let profile = try XCTUnwrap(dict["profile"] as? [String: Any])
        let frames = try XCTUnwrap(profile["frames"] as? [[String: Any]])
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0]["instruction_addr"] as? String, "0x1234")
        XCTAssertEqual(frames[0]["function"] as? String, "main")
        XCTAssertEqual(frames[0]["module"] as? String, "App")
    }

    func testProfilingData_toDictionary_serializesSamples() throws {
        let data = SentryAppHang.ProfilingData(
            frames: [.init(instructionAddress: nil, function: "main", module: nil)],
            stacks: [[0]],
            samples: [.init(absoluteTimestamp: 1_000_000_000, stackIndex: 0, threadId: 259)],
            threadMetadata: [:]
        )
        let dict = data.toDictionary()
        let profile = try XCTUnwrap(dict["profile"] as? [String: Any])
        let samples = try XCTUnwrap(profile["samples"] as? [[String: Any]])
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0]["thread_id"] as? String, "259")
        XCTAssertEqual(samples[0]["stack_id"] as? NSNumber, NSNumber(value: 0))
        // timestamp: 1_000_000_000 ns == 1.0 seconds
        let timestamp = try XCTUnwrap(samples[0]["timestamp"] as? NSNumber)
        XCTAssertEqual(timestamp.doubleValue, 1.0, accuracy: 0.0001)
    }

    func testProfilingData_toDictionary_serializesStacks() throws {
        let data = SentryAppHang.ProfilingData(
            frames: [.init(instructionAddress: nil, function: "a", module: nil),
                     .init(instructionAddress: nil, function: "b", module: nil)],
            stacks: [[0, 1]],
            samples: [],
            threadMetadata: [:]
        )
        let dict = data.toDictionary()
        let profile = try XCTUnwrap(dict["profile"] as? [String: Any])
        let stacks = try XCTUnwrap(profile["stacks"] as? [[NSNumber]])
        XCTAssertEqual(stacks, [[NSNumber(value: 0), NSNumber(value: 1)]])
    }

    func testProfilingData_toDictionary_serializesThreadMetadata() throws {
        let data = SentryAppHang.ProfilingData(
            frames: [],
            stacks: [],
            samples: [],
            threadMetadata: ["1": .init(name: "main", priority: 31)]
        )
        let dict = data.toDictionary()
        let profile = try XCTUnwrap(dict["profile"] as? [String: Any])
        let meta = try XCTUnwrap(profile["thread_metadata"] as? [String: [String: Any]])
        XCTAssertEqual(meta["1"]?["name"] as? String, "main")
        XCTAssertEqual(meta["1"]?["priority"] as? NSNumber, NSNumber(value: 31))
    }

    func testProfilingData_toDictionary_omitsNilFrameFields() throws {
        let data = SentryAppHang.ProfilingData(
            frames: [.init(instructionAddress: nil, function: nil, module: nil)],
            stacks: [[0]],
            samples: [],
            threadMetadata: [:]
        )
        let dict = data.toDictionary()
        let profile = try XCTUnwrap(dict["profile"] as? [String: Any])
        let frames = try XCTUnwrap(profile["frames"] as? [[String: Any]])
        XCTAssertEqual(frames.count, 1)
        XCTAssertTrue(frames[0].isEmpty, "Frame dict should be empty when all fields are nil")
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

private class MockHub: Hub {
    var capturedEnvelopes: [SentryEnvelope] = []

    func configureScope(_ callback: @escaping (Scope) -> Void) {}
    func storeEnvelope(_ envelope: SentryEnvelope) {}
    func captureEnvelope(_ envelope: SentryEnvelope) { capturedEnvelopes.append(envelope) }
    func setTrace(_ traceId: SentryId, spanId: SpanId) {}
    var options: Options { Options() }
}

private struct MockIntegrationDependencies: SentryHangTrackingV3IntegrationDependencies {
    let appHangTracker: SentryAppHangTracker
    let client: SentryClientInternal?
    let hub: Hub
    var threadInspector: SentryThreadInspector { SentryThreadInspector(options: nil) }
    var debugImageProvider: SentryDebugImageProvider { SentryDebugImageProvider() }
}
#endif
