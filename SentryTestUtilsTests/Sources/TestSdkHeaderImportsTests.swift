import _SentryPrivate
#if SWIFT_PACKAGE
import SentryHeaders
#else
import Sentry
#endif
import SentryTestUtilsObjC
import XCTest

// Neither build system uses a bridging header for this target. Verify that main-suite
// dependencies are importable and linked through the shared test-only module.
final class TestSdkHeaderImportsTests: XCTestCase {
    func testDictionaryHeader_whenImported_shouldExposeMerge() {
        // -- Arrange --
        let dictionary = NSMutableDictionary()

        // -- Act --
        SentryDictionary.mergeEntries(from: ["key": "value"], into: dictionary)

        // -- Assert --
        XCTAssertEqual(dictionary["key"] as? String, "value")
    }

    func testFormatterHeader_whenImported_shouldExposeFunctions() {
        // -- Act & Assert --
        XCTAssertEqual(sentry_formatHexAddress(NSNumber(value: 42)), "0x000000000000002a")
        XCTAssertEqual(sentry_stringForUInt64(42), "42")
    }

    func testGeoHeader_whenImported_shouldExposeDictionaryInitializer() throws {
        // -- Act --
        let geo = try XCTUnwrap(Geo(dictionary: ["city": "Vienna"]))

        // -- Assert --
        XCTAssertEqual(geo.city, "Vienna")
    }

    func testStatusCodeHeader_whenImported_shouldExposeRangeCheck() {
        // -- Arrange --
        let range = HttpStatusCodeRange(min: 500, max: 599)

        // -- Act & Assert --
        XCTAssertTrue(range.is(inRange: 503))
        XCTAssertFalse(range.is(inRange: 404))
    }

    func testNotificationHeader_whenImported_shouldExposeHybridNotification() {
        // -- Act & Assert --
        XCTAssertEqual(SentryHybridSdkDidBecomeActiveNotificationName, "SentryHybridSdkDidBecomeActive")
    }

    func testSampleDecisionHeader_whenImported_shouldExposeConversion() {
        // -- Act & Assert --
        XCTAssertNil(valueForSentrySampleDecision(.undecided))
        XCTAssertEqual(valueForSentrySampleDecision(.yes), NSNumber(value: true))
        XCTAssertEqual(valueForSentrySampleDecision(.no), NSNumber(value: false))
    }

    func testWeakMapHeader_whenImported_shouldExposeGenericMap() {
        // -- Arrange --
        let map = SentryWeakMap<NSObject, NSObject>()
        let key = NSObject()
        let value = NSObject()

        // -- Act --
        map.setObject(value, forKey: key)

        // -- Assert --
        XCTAssertTrue(map.object(forKey: key) === value)
    }

    func testFileManagerHeader_whenImported_shouldExposeHelpersWithoutProfiler() {
        // -- Arrange --
        let error = NSError(domain: NSPOSIXErrorDomain, code: Int(ENAMETOOLONG))

        // -- Act & Assert --
        XCTAssertTrue(isErrorPathTooLong(error))
    }

    func testTracerPrivateHeader_whenImported_shouldExposeProfilerReference() {
        // -- Act & Assert --
        XCTAssertNotEqual(\SentryTracer.profilerReferenceID as AnyKeyPath, \SentryTracer.traceId as AnyKeyPath)
    }

    #if os(iOS) || os(macOS)
    func testProfilerStateHeader_whenImported_shouldExposeMutableState() {
        // -- Arrange --
        let state = SentryProfilerState()

        // -- Act & Assert --
        state.mutate { mutableState in
            XCTAssertEqual(mutableState.frames.count, 0)
            XCTAssertEqual(mutableState.stacks.count, 0)
        }
    }

    func testProfilerSerializationHeader_whenImported_shouldExposeFrameKeys() {
        // -- Act & Assert --
        XCTAssertEqual(kSentryProfilerSerializationKeySlowFrameRenders, "slow_frame_renders")
        XCTAssertEqual(kSentryProfilerSerializationKeyFrozenFrameRenders, "frozen_frame_renders")
        XCTAssertEqual(kSentryProfilerSerializationKeyFrameRates, "screen_frame_rates")
    }

    func testMetricProfilerHeader_whenImported_shouldSerializeEmptyMetrics() {
        // -- Act & Assert --
        XCTAssertTrue(serializeContinuousProfileMetrics([:]).isEmpty)
    }
    #endif

    #if !SDK_V10
    func testCrashContextHeader_whenImported_shouldExposeReportContext() {
        // -- Arrange --
        var context = SentryCrash_MonitorContext()

        // -- Act --
        context.crashedDuringCrashHandling = true

        // -- Assert --
        XCTAssertTrue(context.crashedDuringCrashHandling)
        XCTAssertNotNil(sentrycrashcm_machexception_getAPI())
    }

    func testCrashCodecHeader_whenImported_shouldDecodeReportData() throws {
        // -- Arrange --
        let data = Data("{\"key\":\"value\"}".utf8)

        // -- Act --
        let decoded = try SentryCrashJSONCodec.decode(data, options: SentryCrashJSONDecodeOptionNone)

        // -- Assert --
        XCTAssertEqual(decoded as? [String: String], ["key": "value"])
    }

    func testCrashCursorHeader_whenImported_shouldHandleEmptyBacktrace() throws {
        // -- Arrange --
        var cursor = SentryCrashStackCursor()

        // -- Act --
        sentrycrashsc_initWithBacktrace(&cursor, nil, 0, 0)
        let advance = try XCTUnwrap(cursor.advanceCursor)

        // -- Assert --
        XCTAssertFalse(advance(&cursor))
    }

    func testCrashDoctorHeader_whenV9_shouldExposeDiagnosisWithoutResources() {
        // -- Arrange --
        let doctor = SentryCrashDoctor()

        // -- Act & Assert --
        XCTAssertNil(doctor.diagnoseCrash([:]))
    }
    #endif
}
