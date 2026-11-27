enum SentryTestSetup {
    static var isV10: Bool {
        true
    }

    static var isKSCrashEnabled: Bool {
        true
    }

    // Some tests assert on symbols that include the module name.
    static let testPrefix = "SentryTests"
}
