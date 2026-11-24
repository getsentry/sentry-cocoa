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
        #if DEBUG // Test support.
        SentrySDKLog.setOutput { string in
            output.log(string)
        }
        #endif
    }
    
    static func getLogOutput() -> SentryLogOutput {
        #if DEBUG // Test support.
        return SentrySDKLog.getOutput()
        #else
        { print($0) }
        #endif
    }
    
    static func setCurrentDateProvider(_ dateProvider: SentryCurrentDateProvider) {
        #if DEBUG // Test support.
        SentrySDKLog.setDateProvider(dateProvider)
        #endif
    }
}
