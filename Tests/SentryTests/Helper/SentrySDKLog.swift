#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

//Exposing internal/test functions from SentrySDKLog
extension SentrySDKLog {
    static func configureLog(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
        SentrySDKLogSupport.configure(isDebug, diagnosticLevel: diagnosticLevel)
    }
    
    static func setLogOutput(_ output: TestLogOutput) {
        #if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
        SentrySDKLog.setOutput { string in
            output.log(string)
        }
        #endif
    }
    
    static func getLogOutput() -> SentryLogOutput {
        #if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
        return SentrySDKLog.getOutput()
        #else
        { print($0) }
        #endif
    }
    
    static func setCurrentDateProvider(_ dateProvider: SentryCurrentDateProvider) {
        #if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
        SentrySDKLog.setDateProvider(dateProvider)
        #endif
    }
}
