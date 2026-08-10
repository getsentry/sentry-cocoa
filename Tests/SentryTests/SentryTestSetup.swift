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

    // The duplicated V10 test target has a distinct module name. Some UIEventTracker tests
    // assert on symbols that include the module name.
    static var testPrefix: String {
        #if SDK_V10
        "SentryTestsV10"
        #else
        "SentryTests"
        #endif
    }
}
