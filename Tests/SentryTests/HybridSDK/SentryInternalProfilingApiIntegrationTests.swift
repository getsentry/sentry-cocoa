@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

#if !(os(watchOS) || os(tvOS) || os(visionOS))

class SentryInternalProfilingApiIntegrationTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryInternalProfilingApiIntegrationTests.self)

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    // MARK: - Helpers

    private func startSDK() {
        SentrySDK.start { options in
            options.dsn = SentryInternalProfilingApiIntegrationTests.dsnAsString
            options.removeAllIntegrations()
        }
    }

    private func skipIfThreadSanitizer() throws {
        if sentry_threadSanitizerIsPresent() {
            throw XCTSkip("Profiler does not run if thread sanitizer is attached.")
        }
    }

    // MARK: - Accessor

    func testProfiling_shouldBeAccessible() {
        startSDK()

        // -- Act --
        let profiling = SentrySDK.internal.profiling

        // -- Assert --
        XCTAssertNotNil(profiling)
    }

    // MARK: - start

    func testStart_withSDKRunning_shouldReturnNonZero() throws {
        try skipIfThreadSanitizer()
        startSDK()

        // -- Act --
        let startTime = SentrySDK.internal.profiling.start(for: SentryId())

        // -- Assert --
        XCTAssertGreaterThan(startTime, 0)
    }

    func testStart_multipleTraces_shouldReturnDistinctNonZeroTimes() throws {
        try skipIfThreadSanitizer()
        startSDK()

        // -- Act --
        let traceA = SentryId()
        let traceB = SentryId()
        let startTimeA = SentrySDK.internal.profiling.start(for: traceA)
        let startTimeB = SentrySDK.internal.profiling.start(for: traceB)

        // -- Assert --
        XCTAssertGreaterThan(startTimeA, 0)
        XCTAssertGreaterThan(startTimeB, 0)

        // -- Cleanup --
        SentrySDK.internal.profiling.discard(for: traceA)
        SentrySDK.internal.profiling.discard(for: traceB)
    }

    // MARK: - collect

    func testCollect_afterStart_shouldReturnPayload() throws {
        try skipIfThreadSanitizer()
        startSDK()

        // -- Arrange --
        let traceId = SentryId()
        let startTime = SentrySDK.internal.profiling.start(for: traceId)
        Thread.sleep(forTimeInterval: 0.2)

        // -- Act --
        let payload = SentrySDK.internal.profiling.collect(
            between: startTime, and: startTime + 200_000_000, for: traceId
        )

        // -- Assert --
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?["platform"] as? String, "cocoa")
    }

    func testCollect_shouldContainProfileStructure() throws {
        try skipIfThreadSanitizer()
        startSDK()

        // -- Arrange --
        let traceId = SentryId()
        let startTime = SentrySDK.internal.profiling.start(for: traceId)
        Thread.sleep(forTimeInterval: 0.2)

        // -- Act --
        let payload = SentrySDK.internal.profiling.collect(
            between: startTime, and: startTime + 200_000_000, for: traceId
        )

        // -- Assert --
        XCTAssertNotNil(payload?["profile_id"])
        XCTAssertNotNil(payload?["device"])
        let profile = payload?["profile"] as? NSDictionary
        XCTAssertNotNil(profile?["thread_metadata"])
        XCTAssertNotNil(profile?["samples"])
        XCTAssertNotNil(profile?["stacks"])
        XCTAssertNotNil(profile?["frames"])
    }

    func testCollect_shouldContainTransactionInfo() throws {
        try skipIfThreadSanitizer()
        startSDK()

        // -- Arrange --
        let traceId = SentryId()
        let startTime = SentrySDK.internal.profiling.start(for: traceId)
        Thread.sleep(forTimeInterval: 0.2)

        // -- Act --
        let payload = SentrySDK.internal.profiling.collect(
            between: startTime, and: startTime + 200_000_000, for: traceId
        )

        // -- Assert --
        let transaction = try XCTUnwrap(payload?["transaction"] as? NSDictionary)
        XCTAssertGreaterThan(try XCTUnwrap(transaction["active_thread_id"] as? Int64), 0)
    }

    func testCollect_shouldContainDebugMeta() throws {
        try skipIfThreadSanitizer()
        startSDK()

        // -- Arrange --
        let traceId = SentryId()
        let startTime = SentrySDK.internal.profiling.start(for: traceId)
        Thread.sleep(forTimeInterval: 0.2)

        // -- Act --
        let payload = SentrySDK.internal.profiling.collect(
            between: startTime, and: startTime + 200_000_000, for: traceId
        )

        // -- Assert --
        let debugMeta = try XCTUnwrap(payload?["debug_meta"] as? [String: Any])
        let images = try XCTUnwrap(debugMeta["images"] as? [[String: Any]])
        XCTAssertFalse(images.isEmpty)
    }

    func testCollect_withoutStart_shouldReturnNil() {
        startSDK()

        // -- Act --
        let result = SentrySDK.internal.profiling.collect(between: 0, and: 1, for: SentryId())

        // -- Assert --
        XCTAssertNil(result)
    }

    // MARK: - discard

    func testDiscard_afterStart_shouldNotCrash() throws {
        try skipIfThreadSanitizer()
        startSDK()

        // -- Arrange --
        let traceId = SentryId()
        let startTime = SentrySDK.internal.profiling.start(for: traceId)
        XCTAssertGreaterThan(startTime, 0)
        Thread.sleep(forTimeInterval: 0.2)

        // -- Act & Assert (no crash) --
        SentrySDK.internal.profiling.discard(for: traceId)
    }

    func testDiscard_withoutStart_shouldNotCrash() {
        startSDK()

        // -- Act & Assert (no crash) --
        SentrySDK.internal.profiling.discard(for: SentryId())
    }
}

#endif
