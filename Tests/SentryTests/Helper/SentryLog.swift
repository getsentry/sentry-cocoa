@testable import Sentry

typealias SentryLog = Sentry.SentryLog

//Exposing internal/test functions from SentryLog
extension Sentry.SentryLog {
    static func configureLog(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
        SentryLog.configure(isDebug, diagnosticLevel: diagnosticLevel)
    }
    
    static func setLogOutput(_ output: SentryLogOutput) {
        #if TEST || TESTCI
        SentryLog.setOutput(output)
        #endif
    }
    
    static func getLogOutput() -> SentryLogOutput {
        #if TEST || TESTCI
        return SentryLog.getOutput()
        #else
        SentryLogOutput()
        #endif
    }
}
