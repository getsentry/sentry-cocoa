#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
import _SentryPrivate
import SentryProfilerTestSupport
#endif
import SentryTestUtils
import XCTest

#if (!SWIFT_PACKAGE || !SDK_V10) && (os(iOS) || os(macOS))
class SentryAppLaunchProfilingMalformedConfigFileTests: XCTestCase {
    override func setUp() {
        super.setUp()
        removeAppLaunchProfilingConfigFile()
        // These tests write directly, without SDK startup creating the cache directory first.
        XCTAssertTrue(ensureLaunchProfileConfigDirectoryExists())
    }

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }

    func testMalformedConfigFile_CorruptedPlist_DoesNotStartProfilingAndRemovesFile() throws {
        // Create a corrupted plist file that can't be parsed
        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        let corruptedData = Data("this is not a valid plist file {[}".utf8)
        try corruptedData.write(to: configURL)

        XCTAssertTrue(appLaunchProfileConfigFileExists())

        XCTAssertNil(sentry_persistedLaunchProfileConfigurationOptions())

        _sentry_nondeduplicated_startLaunchProfile()

        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }

    func testMalformedConfigFile_ContinuousV2MissingLifecycle_DoesNotStartProfilingAndRemovesFile() throws {
        // Create a config file with continuous profiling v2 enabled but missing lifecycle
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 1.0,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5
            // Missing: kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle
        ]

        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        XCTAssertTrue(appLaunchProfileConfigFileExists())
        XCTAssertNotNil(sentry_persistedLaunchProfileConfigurationOptions())

        _sentry_nondeduplicated_startLaunchProfile()

        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }

    func testMalformedConfigFile_ContinuousV2ManualMissingSampleRate_DoesNotStartProfilingAndRemovesFile() throws {
        // Create a config file with continuous profiling v2 manual lifecycle but missing sample rate
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5
            // Missing: kSentryLaunchProfileConfigKeyProfilesSampleRate
        ]

        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        XCTAssertTrue(appLaunchProfileConfigFileExists())
        XCTAssertNotNil(sentry_persistedLaunchProfileConfigurationOptions())

        _sentry_nondeduplicated_startLaunchProfile()

        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }

    func testMalformedConfigFile_ContinuousV2ManualMissingSampleRand_DoesNotStartProfilingAndRemovesFile() throws {
        // Create a config file with continuous profiling v2 manual lifecycle but missing sample rand
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 1.0
            // Missing: kSentryLaunchProfileConfigKeyProfilesSampleRand
        ]

        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        XCTAssertTrue(appLaunchProfileConfigFileExists())
        XCTAssertNotNil(sentry_persistedLaunchProfileConfigurationOptions())

        _sentry_nondeduplicated_startLaunchProfile()

        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }

    func testMalformedConfigFile_TraceProfilingMissingProfilesRate_DoesNotStartProfilingAndRemovesFile() throws {
        // Create a config file for trace profiling but missing profiles sample rate
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1.0,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5
            // Missing: kSentryLaunchProfileConfigKeyProfilesSampleRate
        ]

        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        XCTAssertTrue(appLaunchProfileConfigFileExists())
        XCTAssertNotNil(sentry_persistedLaunchProfileConfigurationOptions())

        _sentry_nondeduplicated_startLaunchProfile()

        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }

    func testMalformedConfigFile_TraceProfilingMissingProfilesRand_DoesNotStartProfilingAndRemovesFile() throws {
        // Create a config file for trace profiling but missing profiles sample rand
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 1.0,
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1.0,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5
            // Missing: kSentryLaunchProfileConfigKeyProfilesSampleRand
        ]

        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        XCTAssertTrue(appLaunchProfileConfigFileExists())
        XCTAssertNotNil(sentry_persistedLaunchProfileConfigurationOptions())

        _sentry_nondeduplicated_startLaunchProfile()

        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }

    func testMalformedConfigFile_TraceProfilingMissingTracesRate_DoesNotStartProfilingAndRemovesFile() throws {
        // Create a config file for trace profiling but missing traces sample rate
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 1.0,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5
            // Missing: kSentryLaunchProfileConfigKeyTracesSampleRate
        ]

        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        XCTAssertTrue(appLaunchProfileConfigFileExists())
        XCTAssertNotNil(sentry_persistedLaunchProfileConfigurationOptions())

        _sentry_nondeduplicated_startLaunchProfile()

        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }

    func testMalformedConfigFile_TraceProfilingMissingTracesRand_DoesNotStartProfilingAndRemovesFile() throws {
        // Create a config file for trace profiling but missing traces sample rand
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 1.0,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1.0
            // Missing: kSentryLaunchProfileConfigKeyTracesSampleRand
        ]

        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        XCTAssertTrue(appLaunchProfileConfigFileExists())
        XCTAssertNotNil(sentry_persistedLaunchProfileConfigurationOptions())

        _sentry_nondeduplicated_startLaunchProfile()

        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }

    func testMalformedConfigFile_EmptyConfigFile_DoesNotStartProfilingAndRemovesFile() throws {
        // Create an empty but valid plist file
        let configDict: [String: Any] = [:]

        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        XCTAssertTrue(appLaunchProfileConfigFileExists())
        XCTAssertNotNil(sentry_persistedLaunchProfileConfigurationOptions())

        _sentry_nondeduplicated_startLaunchProfile()

        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }

    func testMalformedConfigFile_ContinuousV2TraceLifecycleMissingTracesRate_DoesNotStartProfilingAndRemovesFile() throws {
        // Create a config file with continuous profiling v2 trace lifecycle but missing traces sample rate
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.trace.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 1.0,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5
            // Missing: kSentryLaunchProfileConfigKeyTracesSampleRate
        ]

        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        XCTAssertTrue(appLaunchProfileConfigFileExists())
        XCTAssertNotNil(sentry_persistedLaunchProfileConfigurationOptions())

        _sentry_nondeduplicated_startLaunchProfile()

        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }
}
#endif // os(iOS) || os(macOS)
