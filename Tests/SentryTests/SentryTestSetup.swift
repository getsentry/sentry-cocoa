// This currently exists because we needed to duplicate the test target to link the Sentry+KSCrash variant
// Once SentryCrash is removed, we should also remove this.
enum SentryTestSetup {
    static var isKSCrashEnabled: Bool {
        #if ENABLE_KSCRASH
        true
        #else
        false
        #endif
    }

    // Because we had to duplicate the test target to link the Sentry+KSCrash target we changed the module name
    // some of the UIEventTracker tests assert on the symbol, which includes the module name.`
    static var testPrefix: String {
        #if ENABLE_KSCRASH
        "SentryTests_KSCrash"
        #else
        "SentryTests"
        #endif
    }
}
