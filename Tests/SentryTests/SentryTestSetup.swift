#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#endif
// This currently exists because we needed to duplicate the test target to link the SentryV10 variant
// Once SentryCrash is removed, we should also remove this.
enum SentryTestSetup {
    static var isV10: Bool {
        #if SDK_V10
        true
        #else
        false
        #endif
    }

    static var isKSCrashEnabled: Bool {
        #if SDK_V10
        true
        #else
        false
        #endif
    }

    // Xcode duplicates the V10 test target; SwiftPM keeps one module in both modes.
    // Some error-description and UIEventTracker tests assert on qualified symbols.
    static var testPrefix: String {
        #if SDK_V10 && !SWIFT_PACKAGE
        "SentryTestsV10"
        #else
        "SentryTests"
        #endif
    }
}
