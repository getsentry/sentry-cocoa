@_spi(Private) @testable import Sentry

//Exposing internal/test functions from SentryLog
extension Sentry.SentryLogSwift {
    static func configureLog(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
        SentryLogSwiftSupport.configure(isDebug, diagnosticLevel: diagnosticLevel)
    }
    
    static func setLogOutput(_ output: SentryLogOutput) {
        #if SENTRY_TEST || SENTRY_TEST_CI
        SentryLogSwift.setOutput(output)
        #endif
    }
    
    static func getLogOutput() -> SentryLogOutput {
        #if SENTRY_TEST || SENTRY_TEST_CI
        return SentryLogSwift.getOutput()
        #else
        SentryLogOutput()
        #endif
    }
    
    static func setCurrentDateProvider(_ dateProvider: SentryCurrentDateProvider) {
        #if SENTRY_TEST || SENTRY_TEST_CI
        SentryLogSwift.setDateProvider(dateProvider)
        #endif
    }
}
