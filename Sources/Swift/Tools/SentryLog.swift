@_implementationOnly import _SentryPrivate
import Foundation

@objc
class SentryLog: NSObject {
    
    static private(set) var isDebug = true
    static private(set) var diagnosticLevel = SentryLevel.error
    private static var logOutput = SentryLogOutput()
    private static var logConfigureLock = NSLock()

    @objc
    static func configure(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
        logConfigureLock.synchronized {
            self.isDebug = isDebug
            self.diagnosticLevel = diagnosticLevel
        }
        sentry_initializeAsyncLogFile()
    }
    
    @objc
    static func log(message: String, andLevel level: SentryLevel) {
        guard willLog(atLevel: level) else { return }
        logOutput.log("[Sentry] [\(level)] \(message)")
    }

    /**
     * @return @c YES if the current logging configuration will log statements at the current level,
     * @c NO if not.
     */
    @objc
    static func willLog(atLevel level: SentryLevel) -> Bool {
        return isDebug && level != .none && level.rawValue >= diagnosticLevel.rawValue
    }
 
    #if TEST
    
    @objc
    static func setOutput(_ output: SentryLogOutput) {
        logOutput = output
    }
    
    static func getOutput() -> SentryLogOutput {
        return logOutput
    }
    
    #endif
}
