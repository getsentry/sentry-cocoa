@_spi(Private) @testable import Sentry

//Exposing internal/test functions from SentryLog
extension Sentry.SentrySDKLog {
    static func configureLog(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
        SentrySDKLogSupport.configure(isDebug, diagnosticLevel: diagnosticLevel)
    }
    
    static func setLogOutput(_ output: SentryLogOutput) {
        #if SENTRY_TEST || SENTRY_TEST_CI
        SentrySDKLog.setOutput(output)
        #endif
    }
    
    static func getLogOutput() -> SentryLogOutput {
        #if SENTRY_TEST || SENTRY_TEST_CI
        return SentrySDKLog.getOutput()
        #else
        SentryLogOutput()
        #endif
    }
    
    static func setCurrentDateProvider(_ dateProvider: SentryCurrentDateProvider) {
        #if SENTRY_TEST || SENTRY_TEST_CI
        SentrySDKLog.setDateProvider(dateProvider)
        #endif
    }
}
