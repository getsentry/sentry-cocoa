#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit
#endif

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
        exception.threadId = thread.threadId
        exception.stacktrace = thread.stacktrace
        
        return exception
    }
    
    static var mechanism: Mechanism {
        let currentDateProvider = TestCurrentDateProvider()
        let mechanism = Mechanism(type: "type")
        mechanism.data = ["something": ["date": currentDateProvider.date()]]
        mechanism.desc = "desc"
        mechanism.handled = true
        mechanism.helpLink = "https://www.sentry.io"
        mechanism.meta = mechanismMeta
        
        return mechanism
    }
    
    static var mechanismMeta: MechanismMeta {
        let mechanismMeta = MechanismMeta()
        mechanismMeta.machException = [
            "name": "EXC_BAD_ACCESS",
            "exception": 1,
            "subcode": 8,
            "code": 0
        ]
        mechanismMeta.signal = [
            "number": 10,
            "code": 0,
            "name": "SIGBUS",
            "code_name": "BUS_NOOP"
        ]
        
        mechanismMeta.error = SentryNSError(domain: "SentrySampleDomain", code: 1)
        
        return mechanismMeta
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
        frame.stackStart = true
        
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
        return SentryAppState(releaseName: "1.0.0", osVersion: "14.4.1", isDebugging: false, systemBootTimestamp: timestamp)
    }
    
    static var oomEvent: Event {
        let event = Event(level: SentryLevel.fatal)
        let exception = Exception(value: SentryOutOfMemoryExceptionValue, type: SentryOutOfMemoryExceptionType)
        exception.mechanism = Mechanism(type: SentryOutOfMemoryMechanismType)
        event.exceptions = [exception]
        return event
    }
    
    static func scopeWith(observer: SentryScopeObserver) -> Scope {
        let scope = Scope()
        scope.add(observer)
        
        scope.setUser(TestData.user)
        scope.setDist("dist")
        setContext(scope)
        scope.setEnvironment("Production")
        
        let tags = ["tag1": "tag1", "tag2": "tag2"]
        scope.setTags(tags)
        scope.setExtras(["extra1": "extra1", "extra2": "extra2"])
        scope.setFingerprint(["finger", "print"])
        
        scope.setLevel(SentryLevel.fatal)
        
        let crumb1 = TestData.crumb
        crumb1.message = "Crumb 1"
        scope.add(crumb1)

        let crumb2 = TestData.crumb
        crumb2.message = "Crumb 2"
        scope.add(crumb2)
        
        return scope
    }
    
    static func setContext(_ scope: Scope) {
        scope.setContext(value: TestData.context["context"]!, key: "context")
    }
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    private static var maximumFramesPerSecond: Int {
        if #available(iOS 10.3, tvOS 10.3, macCatalyst 13.0, *) {
            return UIScreen.main.maximumFramesPerSecond
        } else {
            return 60
        }
    }
    
    static var slowFrameThreshold: Double {
        return 1 / (Double(maximumFramesPerSecond) - 1.0)
    }
    
    static let frozenFrameThreshold = 0.7
    #endif
    
    static func getAppStartMeasurement(type: SentryAppStartType, appStartTimestamp: Date = TestData.timestamp) -> SentryAppStartMeasurement {
        let appStartDuration = 0.5
        let runtimeInit = appStartTimestamp.addingTimeInterval(0.2)
        let didFinishLaunching = appStartTimestamp.addingTimeInterval(0.3)
        
        return SentryAppStartMeasurement(type: type, appStartTimestamp: appStartTimestamp, duration: appStartDuration, runtimeInitTimestamp: runtimeInit, didFinishLaunchingTimestamp: didFinishLaunching)
    }
}
