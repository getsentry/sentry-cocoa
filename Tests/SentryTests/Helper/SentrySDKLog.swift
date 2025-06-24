@_spi(Private) @testable import Sentry

//Exposing internal/test functions from SentrySDKLog
extension Sentry.SentrySDKLog {
    static func configureLog(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
        SentrySDKLogSupport.configure(isDebug, diagnosticLevel: diagnosticLevel)
    }
    
    static func setLogOutput(_ output: TestLogOutput) {
        #if SENTRY_TEST || SENTRY_TEST_CI
        SentrySDKLog.setOutput { string in
            output.log(string)
        }
        #endif
    }
    
    static func getLogOutput() -> SentryLogOutput {
        #if SENTRY_TEST || SENTRY_TEST_CI
        return SentrySDKLog.getOutput()
        #else
        { print($0) }
        #endif
    }
    
    static func setCurrentDateProvider(_ dateProvider: SentryCurrentDateProvider) {
        #if SENTRY_TEST || SENTRY_TEST_CI
        SentrySDKLog.setDateProvider(dateProvider)
        #endif
    }
}
