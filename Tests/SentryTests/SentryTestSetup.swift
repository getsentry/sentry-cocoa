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

    // Some tests assert on symbols that include the module name.
    static let testPrefix = "SentryTests"
}
