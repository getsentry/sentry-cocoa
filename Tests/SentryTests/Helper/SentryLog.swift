@_spi(Private) @testable import Sentry

//Exposing internal/test functions from SentryLog
extension Sentry.SentryLog {
    static func configureLog(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
        SentryLogSwiftSupport.configure(isDebug, diagnosticLevel: diagnosticLevel)
    }
    
    static func setLogOutput(_ output: TestLogOutput) {
        #if SENTRY_TEST || SENTRY_TEST_CI
        SentryLog.setOutput { string in
            output.log(string)
        }
        #endif
    }
    
    static func getLogOutput() -> SentryLogOutput {
        #if SENTRY_TEST || SENTRY_TEST_CI
        return SentryLog.getOutput()
        #else
        { print($0) }
        #endif
    }
    
    static func setCurrentDateProvider(_ dateProvider: SentryCurrentDateProvider) {
        #if SENTRY_TEST || SENTRY_TEST_CI
        SentryLog.setDateProvider(dateProvider)
        #endif
    }
}
