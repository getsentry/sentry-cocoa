enum SentryTestSetup {
    static var isKSCrashEnabled: Bool {
        #if ENABLE_KSCRASH
        true
        #else
        false
        #endif
    }
}
