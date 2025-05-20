@testable import Sentry

typealias SentryLog = Sentry.SentryLog

//Exposing internal/test functions from SentryLog
extension Sentry.SentryLog {
    static func configureLog(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
        SentryLogSwiftSupport.configure(isDebug, diagnosticLevel: diagnosticLevel)
    }
    
    static func setLogOutput(_ output: SentryLogOutput) {
        #if SENTRY_TEST || SENTRY_TEST_CI
        SentryLog.setOutput(output)
        #endif
    }
    
    static func getLogOutput() -> SentryLogOutput {
        #if SENTRY_TEST || SENTRY_TEST_CI
        return SentryLog.getOutput()
        #else
        SentryLogOutput()
        #endif
    }
    
    static func setCurrentDateProvider(_ dateProvider: SentryCurrentDateProvider) {
        #if SENTRY_TEST || SENTRY_TEST_CI
        SentryLog.setDateProvider(dateProvider)
        #endif
    }
}
