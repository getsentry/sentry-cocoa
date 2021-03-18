import Foundation

class TestData {
    
    static let timestamp = Date(timeIntervalSince1970: 10)
    static var timestampAs8601String: String {
        get {
            (timestamp as NSDate).sentry_toIso8601String()
        }
    }
    static let sdk = ["name": SentryMeta.sdkName, "version": SentryMeta.versionString]
    static let context = ["context": ["c": "a"]]
    
    static var crumb: Breadcrumb {
        let crumb = Breadcrumb()
        crumb.level = SentryLevel.info
        crumb.timestamp = timestamp
        crumb.type = "user"
        crumb.message = "Clicked something"
        crumb.data = ["some": ["data": "data", "date": timestamp]]
        return crumb
    }
    
    static var event: Event {
        let event = Event(level: SentryLevel.info)
        
        event.breadcrumbs = [crumb]
        event.context = context
        event.debugMeta = [debugMeta]
        event.dist = "dist"
        event.environment = "environment"
        event.exceptions = [exception]
        event.extra = ["some": "extra"]
        event.fingerprint = ["fingerprint"]
        event.logger = "logger"
        event.message = SentryMessage(formatted: "message")
        event.modules = ["module": "1"]
        event.platform = "Apple"
        event.releaseName = SentryMeta.versionString
        event.sdk = sdk
        event.serverName = "serverName"
        event.stacktrace = stacktrace
        event.startTimestamp = timestamp
        event.tags = ["tag": "tag"]
        event.threads = [thread]
        event.timestamp = timestamp
        event.transaction = "transaction"
        event.type = "type"
        event.user = user
        
        return event
    }
    
    static var user: User {
        let user = User(userId: "id")
        user.email = "user@sentry.io"
        user.username = "user123"
        user.ipAddress = "127.0.0.1"
        user.data = ["some": ["data": "data", "date": timestamp]]
        
        return user
    }
    
    static var debugMeta: DebugMeta {
        let debugMeta = DebugMeta()
        debugMeta.imageAddress = "0x0000000105705000"
        debugMeta.imageSize = 352_256
        debugMeta.imageVmAddress = "0x00007fff51af0000"
        debugMeta.name = "/tmp/scratch/dyld_sim"
        debugMeta.type = "apple"
        debugMeta.uuid = "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322"
        
        return debugMeta
    }
    
    static var exception: Exception {
        let exception = Exception(value: "value", type: "type")
        exception.mechanism = mechanism
        exception.module = "module"
        exception.thread = thread
        
        return exception
    }
    
    static var mechanism: Mechanism {
        let currentDateProvider = TestCurrentDateProvider()
        let mechanism = Mechanism(type: "type")
        mechanism.data = ["something": ["date": currentDateProvider.date()]]
        mechanism.desc = "desc"
        mechanism.handled = true
        mechanism.helpLink = "https://www.sentry.io"
        mechanism.meta = ["meta": "data"]
        
        let error = SampleError.bestDeveloper as NSError
        mechanism.error = SentryNSError(domain: error.domain, code: error.code)
        
        return mechanism
    }
    
    static var thread: Sentry.Thread {
        let thread = Sentry.Thread(threadId: 10)
        thread.crashed = false
        thread.current = true
        thread.name = "main"
        thread.stacktrace = stacktrace
        
        return thread
    }
    
    static var stacktrace: Stacktrace {
        let stacktrace = Stacktrace(frames: [frame], registers: ["register": "one"])
        return stacktrace
    }
    
    static var frame: Frame {
        let frame = Frame()
        frame.columnNumber = 1
        frame.fileName = "fileName"
        frame.function = "main"
        frame.imageAddress = "0x0000000105705000"
        frame.inApp = true
        frame.instructionAddress = "0x000000008fd09c40"
        frame.lineNumber = 207
        frame.module = "module"
        frame.package = "sentry"
        frame.platform = "iOS"
        frame.symbolAddress = "0x000000008e902bf0"
        
        return frame
    }
    
    static var fileAttachment: Attachment {
        return Attachment(path: "path/to/file.txt", filename: "file.txt")
    }
    
    static var dataAttachment: Attachment {
        return Attachment(data: "hello".data(using: .utf8)!, filename: "file.txt")
    }
    
    enum SampleError: Error {
        case bestDeveloper
        case happyCustomer
        case awesomeCentaur
    }
    
    static var appState: SentryAppState {
        return SentryAppState(appVersion: "1.0.0", osVersion: "14.4.1", isDebugging: false)
    }
    
    static var oomEvent: Event {
        let event = Event(level: SentryLevel.fatal)
        let exception = Exception(value: SentryOutOfMemoryExceptionValue, type: SentryOutOfMemoryExceptionType)
        exception.mechanism = Mechanism(type: SentryOutOfMemoryExceptionType)
        event.exceptions = [exception]
        return event
    }
}
