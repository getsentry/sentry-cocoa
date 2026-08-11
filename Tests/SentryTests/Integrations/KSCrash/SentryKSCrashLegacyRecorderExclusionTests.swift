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
            "sentrycrashstring_extractHexValue"
        ]

        for symbol in symbols {
            XCTAssertNil(dlsym(UnsafeMutableRawPointer(bitPattern: -2), symbol), "Unexpected SentryCrash symbol: \(symbol)")
        }
    }

    func testScopeSync_whenBuildingV10_shouldCompileAndLinkSDKOwnedAPI() throws {
        let json = #"{"value":"v10"}"#
        sentrycrash_scopesync_reset()
        defer {
            sentrycrash_scopesync_setTraceContext(nil)
            sentrycrash_scopesync_reset()
        }

        sentrycrash_scopesync_configureBreadcrumbs(1)
        json.withCString { jsonCString in
            sentrycrash_scopesync_setUser(jsonCString)
            sentrycrash_scopesync_setDist(jsonCString)
            sentrycrash_scopesync_setContext(jsonCString)
            sentrycrash_scopesync_setTraceContext(jsonCString)
            sentrycrash_scopesync_setEnvironment(jsonCString)
            sentrycrash_scopesync_setTags(jsonCString)
            sentrycrash_scopesync_setExtras(jsonCString)
            sentrycrash_scopesync_setFingerprint(jsonCString)
            sentrycrash_scopesync_setLevel(jsonCString)
            sentrycrash_scopesync_addBreadcrumb(jsonCString)
        }

        let scope = try XCTUnwrap(sentrycrash_scopesync_getScope())
        XCTAssertEqual(String(cString: try XCTUnwrap(scope.pointee.user)), json)
        XCTAssertEqual(String(cString: try XCTUnwrap(scope.pointee.dist)), json)
        XCTAssertEqual(String(cString: try XCTUnwrap(scope.pointee.context)), json)
        XCTAssertEqual(String(cString: try XCTUnwrap(scope.pointee.traceContext)), json)
        XCTAssertEqual(String(cString: try XCTUnwrap(scope.pointee.environment)), json)
        XCTAssertEqual(String(cString: try XCTUnwrap(scope.pointee.tags)), json)
        XCTAssertEqual(String(cString: try XCTUnwrap(scope.pointee.extras)), json)
        XCTAssertEqual(String(cString: try XCTUnwrap(scope.pointee.fingerprint)), json)
        XCTAssertEqual(String(cString: try XCTUnwrap(scope.pointee.level)), json)

        let breadcrumbs = try XCTUnwrap(scope.pointee.breadcrumbs)
        XCTAssertEqual(String(cString: try XCTUnwrap(breadcrumbs[0])), json)
        sentrycrash_scopesync_clearBreadcrumbs()
        XCTAssertNil(breadcrumbs[0])

        sentrycrash_scopesync_clear()
        XCTAssertNil(scope.pointee.user)
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
