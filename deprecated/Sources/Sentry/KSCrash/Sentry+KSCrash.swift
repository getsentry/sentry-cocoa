import KSCrash
import Sentry

extension SentryClient {
    /*
     Captures current stracktrace of the thread and stores it in internal var stacktraceSnapshot
     Use event.fetchStacktrace() to fill your event with this stacktrace
     */
    @objc public func snapshotStacktrace() {
        guard let crashHandler = crashHandler else {
            Log.Error.log("crashHandler not yet initialized")
            return
        }
        KSCrash.sharedInstance().reportUserException("", reason: "", language: "", lineOfCode: "", stackTrace: [""], logAllThreads: false, terminateProgram: false)
        crashHandler.sendAllReports()
    }

    @objc public func reportReactNativeCrash(error: NSError, stacktrace: [AnyType], terminateProgram: Bool) {
        guard let crashHandler = crashHandler else {
            Log.Error.log("crashHandler not yet initialized")
            return
        }
        KSCrash.sharedInstance().reportUserException(error.localizedDescription,
                                                     reason: "",
                                                     language: CrashLanguages.reactNative,
                                                     lineOfCode: "",
                                                     stackTrace: stacktrace,
                                                     logAllThreads: true,
                                                     terminateProgram: terminateProgram)
        crashHandler.sendAllReports()
    }
}
