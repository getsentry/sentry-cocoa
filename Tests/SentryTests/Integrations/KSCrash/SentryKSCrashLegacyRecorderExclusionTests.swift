#if SENTRY_DISABLE_SENTRYCRASH_V10
import Darwin
import Foundation
import XCTest

final class SentryKSCrashLegacyRecorderExclusionTests: XCTestCase {
    private static let compatibilitySymbolAllowlist = [
        "__sentry_cxa_throw",
        "__sentry_cxa_rethrow"
    ]

    func testKSCrashBuild_whenInspectingRuntime_shouldNotContainExcludedSentryCrashSymbols() {
        let symbols = [
            "sentrycrash_install",
            "sentrycrashcm_signal_getAPI",
            "sentrycrashcm_machexception_getAPI",
            "sentrycrashcm_cppexception_getAPI",
            "sentrycrashcm_nsexception_getAPI",
            "sentrycrashbic_startCache",
            "sentrycrashcrs_initialize",
            "sentrycrashdate_utcStringFromTimestamp",
            "sentrycrashdebug_isBeingTraced",
            "sentrycrashdl_initialize",
            "sentrycrashid_generate",
            "sentrycrash_macho_getCommandByTypeFromHeader",
            "sentrycrashmach_exceptionName",
            "sentryErrorWithDomain",
            "sentrycrashobjc_objectType",
            "sentrycrashsignal_signalName",
            "sentrycrashstring_extractHexValue",
            "sentrycrash_scopesync_getScope"
        ]

        for symbol in symbols {
            XCTAssertNil(dlsym(UnsafeMutableRawPointer(bitPattern: -2), symbol), "Unexpected SentryCrash symbol: \(symbol)")
        }
    }

    func testKSCrashBuild_whenInspectingRuntime_shouldContainCompatibilitySymbols() {
        for symbol in Self.compatibilitySymbolAllowlist {
            XCTAssertNotNil(dlsym(UnsafeMutableRawPointer(bitPattern: -2), symbol), "Missing compatibility symbol: \(symbol)")
        }
    }

    func testKSCrashBuild_whenInspectingRuntime_shouldNotContainSentryCrashRecorderClasses() {
        let classes = [
            "SentryCrash",
            "SentryCrashBridge",
            "SentryCrashInstallation",
            "SentryCrashJSONCodec",
            "SentryCrashReportSink",
            "SentryCrashScopeObserver",
            "SentryCrashSwift",
            "SentryDefaultCrashReporter"
        ]

        for className in classes {
            XCTAssertNil(NSClassFromString(className), "Unexpected SentryCrash class: \(className)")
        }
    }
}
#endif // SENTRY_DISABLE_SENTRYCRASH_V10
