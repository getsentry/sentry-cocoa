import _SentryPrivate
import Foundation
import Sentry
import XCTest

class SentryBaggageTests: XCTestCase {
    // MARK: - Tests without sampleRand

    func test_baggageToHeader_AppendToOriginal() {
        let header = Baggage(trace: SentryId.empty, publicKey: "publicKey", releaseName: "release name", environment: "teste", transaction: "transaction", userSegment: "test user", sampleRate: "0.49", sampled: "true", replayId: "some_replay_id").toHTTPHeader(withOriginalBaggage: ["a": "a", "sentry-trace_id": "to-be-overwritten"])

        XCTAssertEqual(header, "a=a,sentry-environment=teste,sentry-public_key=publicKey,sentry-release=release%20name,sentry-replay_id=some_replay_id,sentry-sample_rate=0.49,sentry-sampled=true,sentry-trace_id=00000000000000000000000000000000,sentry-transaction=transaction,sentry-user_segment=test%20user")
    }

    func test_baggageToHeader_onlyTrace_ignoreNils() {
        let header = Baggage(trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: nil, transaction: nil, userSegment: nil, sampleRate: nil, sampled: nil, replayId: nil).toHTTPHeader(withOriginalBaggage: nil)

        XCTAssertEqual(header, "sentry-public_key=publicKey,sentry-trace_id=00000000000000000000000000000000")
    }

    // MARK: - Tests with sampleRand

    func testWithSampleRand_baggageToHeader_AppendToOriginal() {
        // -- Arrange --
        let baggage = Baggage(
            trace: SentryId.empty, publicKey: "publicKey", releaseName: "release name", environment: "teste",
            transaction: "transaction", userSegment: "test user",
            sampleRate: "0.49", sampleRand: "0.6543", sampled: "true",
            replayId: "some_replay_id"
        )

        // -- Act --
        let header = baggage.toHTTPHeader(withOriginalBaggage: ["a": "a", "sentry-trace_id": "to-be-overwritten"])

        // -- Assert --
        XCTAssertEqual(header, "a=a,sentry-environment=teste,sentry-public_key=publicKey,sentry-release=release%20name,sentry-replay_id=some_replay_id,sentry-sample_rand=0.6543,sentry-sample_rate=0.49,sentry-sampled=true,sentry-trace_id=00000000000000000000000000000000,sentry-transaction=transaction,sentry-user_segment=test%20user")
    }

    func testWithSampleRand_baggageToHeader_onlyTrace_ignoreNils() {
        // -- Arrange --
        let baggage = Baggage(
            trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: nil,
            transaction: nil, userSegment: nil,
            sampleRate: nil, sampleRand: nil, sampled: nil, replayId: nil
        )

        // -- Act --
        let header = baggage.toHTTPHeader(withOriginalBaggage: nil)

        // -- Assert --
        XCTAssertEqual(header, "sentry-public_key=publicKey,sentry-trace_id=00000000000000000000000000000000")
    }

    func testToHTTPHeader_releaseNameInOriginalBaggage_shouldBeOverwritten() {
        // -- Arrange --
        let baggage = Baggage(
            trace: SentryId.empty, publicKey: "publicKey", releaseName: "release name", environment: nil,
            transaction: nil, userSegment: nil,
            sampleRate: nil, sampleRand: nil, sampled: nil, replayId: nil
        )

        // -- Act --
        let header = baggage.toHTTPHeader(withOriginalBaggage: ["sentry-release": "original release name"])

        // -- Assert --
        XCTAssertEqual(header, "sentry-public_key=publicKey,sentry-release=release%20name,sentry-trace_id=00000000000000000000000000000000")
    }

    func testToHTTPHeader_environmentInOriginalBaggage_shouldBeOverwritten() {
        // -- Arrange --
        let baggage = Baggage(
            trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: "environment",
            transaction: nil, userSegment: nil,
            sampleRate: nil, sampleRand: nil, sampled: nil, replayId: nil
        )

        // -- Act --
        let header = baggage.toHTTPHeader(withOriginalBaggage: ["sentry-environment": "original environment"])

        // -- Assert --
        XCTAssertEqual(header, "sentry-environment=environment,sentry-public_key=publicKey,sentry-trace_id=00000000000000000000000000000000")
    }

    func testToHTTPHeader_transactionInOriginalBaggage_shouldBeOverwritten() {
        // -- Arrange --
        let baggage = Baggage(
            trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: nil,
            transaction: "transaction", userSegment: nil,
            sampleRate: nil, sampleRand: nil, sampled: nil, replayId: nil
        )

        // -- Act --
        let header = baggage.toHTTPHeader(withOriginalBaggage: ["sentry-transaction": "original transaction"])

        // -- Assert --
        XCTAssertEqual(header, "sentry-public_key=publicKey,sentry-trace_id=00000000000000000000000000000000,sentry-transaction=transaction")
    }

    func testToHTTPHeader_userSegmentInOriginalBaggage_shouldBeOverwritten() {
        // -- Arrange --
        let baggage = Baggage(
            trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: nil,
            transaction: nil, userSegment: "segment",
            sampleRate: nil, sampleRand: nil, sampled: nil, replayId: nil
        )

        // -- Act --
        let header = baggage.toHTTPHeader(withOriginalBaggage: ["sentry-user_segment": "original segment"])

        // -- Assert --
        XCTAssertEqual(header, "sentry-public_key=publicKey,sentry-trace_id=00000000000000000000000000000000,sentry-user_segment=segment")
    }

    func testToHTTPHeader_sampleRateInOriginalBaggage_shouldBeOverwritten() {
        // -- Arrange --
        let baggage = Baggage(
            trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: nil,
            transaction: nil, userSegment: nil,
            sampleRate: "1.0", sampleRand: nil, sampled: nil, replayId: nil
        )

        // -- Act --
        let header = baggage.toHTTPHeader(withOriginalBaggage: ["sentry-sample_rate": "0.1"])

        // -- Assert --
        XCTAssertEqual(header, "sentry-public_key=publicKey,sentry-sample_rate=1.0,sentry-trace_id=00000000000000000000000000000000")
    }

    func testToHTTPHeader_sampleRandInOriginalBaggage_shouldBeOverwritten() {
        // -- Arrange --
        let baggage = Baggage(
            trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: nil,
            transaction: nil, userSegment: nil,
            sampleRate: nil, sampleRand: "0.5", sampled: nil, replayId: nil
        )

        // -- Act --
        let header = baggage.toHTTPHeader(withOriginalBaggage: ["sentry-sample_rand": "0.1"])

        // -- Assert --
        XCTAssertEqual(header, "sentry-public_key=publicKey,sentry-sample_rand=0.5,sentry-trace_id=00000000000000000000000000000000")
    }

    func testToHTTPHeader_sampledInOriginalBaggage_shouldBeOverwritten() {
        // -- Arrange --
        let baggage = Baggage(
            trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: nil,
            transaction: nil, userSegment: nil,
            sampleRate: nil, sampleRand: nil, sampled: "true", replayId: nil
        )

        // -- Act --
        let header = baggage.toHTTPHeader(withOriginalBaggage: ["sentry-sampled": "false"])

        // -- Assert --
        XCTAssertEqual(header, "sentry-public_key=publicKey,sentry-sampled=true,sentry-trace_id=00000000000000000000000000000000")
    }

    func testToHTTPHeader_replayIdInOriginalBaggage_shouldBeOverwritten() {
        // -- Arrange --
        let baggage = Baggage(
            trace: SentryId.empty, publicKey: "publicKey", releaseName: nil, environment: nil,
            transaction: nil, userSegment: nil,
            sampleRate: nil, sampleRand: nil, sampled: nil, replayId: "replay-id"
        )

        // -- Act --
        let header = baggage.toHTTPHeader(withOriginalBaggage: ["sentry-replay_id": "original-replay-id"])

        // -- Assert --
        XCTAssertEqual(header, "sentry-public_key=publicKey,sentry-replay_id=replay-id,sentry-trace_id=00000000000000000000000000000000")
    }
}
