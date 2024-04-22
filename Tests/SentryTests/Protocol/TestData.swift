import Sentry
import SentryTestUtils

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit
#endif

class TestData {
    
    static let timestamp = Date(timeIntervalSince1970: 10)
    static let systemTimestamp: UInt64 = 10 * 1_000_000_000 // 10 seconds, in nanoseconds
    static var timestampAs8601String: String {
        sentry_toIso8601String(timestamp as Date)
    }
    static let sdk = ["name": SentryMeta.sdkName, "version": SentryMeta.versionString]
    static let context: [String: [String: Any]] = ["context": ["c": "a", "date": timestamp]]
    
    static let malformedURLString = "http://example.com:-80/"
    
    static var crumb: Breadcrumb {
        let crumb = Breadcrumb()
        crumb.level = SentryLevel.info
        crumb.timestamp = timestamp
        crumb.type = "user"
        crumb.message = "Clicked something"
        crumb.data = ["some": ["data": "data", "date": timestamp] as [String: Any]]
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
        event.request = request
        
        return event
    }
    
    static var user: User {
        let user = User(userId: "id")
        user.email = "user@sentry.io"
        user.username = "user123"
        user.ipAddress = "127.0.0.1"
        user.segment = "segmentA"
        user.name = "User"
        user.geo = geo
        user.data = ["some": ["data": "data", "date": timestamp] as [String: Any]] 
        
        return user
    }
    
    static var geo: Geo {
        let geo = Geo()
        geo.city = "Vienna"
        geo.countryCode = "at"
        geo.region = "Vienna"
        return geo
    }
    
    static var debugMeta: DebugMeta {
        let debugMeta = DebugMeta()
        debugMeta.imageAddress = "0x0000000105705000"
        debugMeta.imageSize = 352_256
        debugMeta.imageVmAddress = "0x00007fff51af0000"
        debugMeta.name = "/tmp/scratch/dyld_sim"
        debugMeta.codeFile = "/tmp/scratch/dyld_sim"
        debugMeta.type = "macho"
        debugMeta.uuid = "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322"
        debugMeta.debugID = "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF321"
        
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
        mechanism.synthetic = false
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
    
    static var thread: SentryThread {
        let thread = SentryThread(threadId: 10)
        thread.crashed = false
        thread.current = true
        thread.name = "main"
        thread.stacktrace = stacktrace
        thread.isMain = true
        
        return thread
    }

    static var thread2: SentryThread {
        let thread = SentryThread(threadId: 0)
        thread.crashed = false
        thread.current = true
        thread.name = "main"
        thread.stacktrace = stacktrace2

        return thread
    }
    
    static var stacktrace: SentryStacktrace {
        let stacktrace = SentryStacktrace(frames: [mainFrame], registers: ["register": "one"])
        stacktrace.snapshot = true
        return stacktrace
    }

    static var stacktrace2: SentryStacktrace {
        let stacktrace = SentryStacktrace(frames: [mainFrame, testFrame], registers: ["register": "one"])
        stacktrace.snapshot = true
        return stacktrace
    }
    
    static var mainFrame: Frame {
        let frame = Frame()
        frame.columnNumber = 1
        frame.fileName = "fileName"
        frame.function = "main"
        frame.imageAddress = "0x0000000105705000"
        frame.inApp = true
        frame.instructionAddress = "0x000000008fd09c40"
        frame.lineNumber = 207
        frame.module = "module"
        frame.package = "sentrytest"
        frame.platform = "iOS"
        frame.symbolAddress = "0x000000008e902bf0"
        frame.stackStart = true
        
        return frame
    }

    static var testFrame: Frame {
        let frame = Frame()
        frame.columnNumber = 1
        frame.fileName = "testFile"
        frame.function = "test"
        frame.imageAddress = "0x0000000105705000"
        frame.inApp = true
        frame.instructionAddress = "0x000000008fd09c90"
        frame.lineNumber = 107
        frame.module = "module"
        frame.package = "sentrytest"
        frame.platform = "iOS"
        frame.symbolAddress = "0x000000008e902b97"
        frame.stackStart = false
        return frame
    }

    static var outsideFrame: Frame {
        let frame = Frame()
        frame.columnNumber = 1
        frame.fileName = "helperFile"
        frame.function = "helper"
        frame.imageAddress = "0x0000000105709000"
        frame.inApp = false
        frame.instructionAddress = "0x000000008fd09a40"
        frame.lineNumber = 307
        frame.module = "outsideModule"
        frame.package = "ThirdPartyLib"
        frame.platform = "iOS"
        frame.symbolAddress = "0x000000008e902e51"
        frame.stackStart = false
        return frame
    }

    static var debugImage: DebugMeta {
        let image = DebugMeta()
        image.name = "sentrytest"
        image.imageAddress = "0x0000000105705000"
        image.imageVmAddress = "0x0000000105705000"
        return image
    }
    
    static var fileAttachment: Attachment {
        return Attachment(path: "path/to/file.txt", filename: "file.txt")
    }
    
    static var dataAttachment: Attachment {
        return Attachment(data: "hello".data(using: .utf8)!, filename: "file.txt")
    }

    static var spanContext: SpanContext {
        SpanContext(operation: "Test Context")
    }
    
    enum SampleError: Error {
        case bestDeveloper
        case happyCustomer
        case awesomeCentaur
    }
    
    static var someUUID = "12345678-1234-1234-1234-12344567890AB"
    
    static var appState: SentryAppState {
        return SentryAppState(releaseName: "1.0.0", osVersion: "14.4.1", vendorId: someUUID, isDebugging: false, systemBootTimestamp: timestamp)
    }
    
    static var appMemory: SentryAppMemory {
        return SentryAppMemory(footprint: 500, remaining: 500, pressure: .normal)
    }
    
    static var oomEvent: Event {
        let event = Event(level: SentryLevel.fatal)
        let exception = Exception(value: SentryWatchdogTerminationExceptionValue, type: SentryWatchdogTerminationExceptionType)
        exception.mechanism = Mechanism(type: SentryWatchdogTerminationMechanismType)
        event.exceptions = [exception]
        return event
    }

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    
    static var metricKitEvent: Event {
        let event = Event(level: .warning)
        let exception = Exception(value: "MXCPUException totalCPUTime:90.009 sec totalSampledTime:91.952 sec", type: SentryMetricKitCpuExceptionType)
        exception.mechanism = Mechanism(type: SentryMetricKitCpuExceptionMechanism)
        event.exceptions = [exception]
        return event
    }

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    
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
        scope.addBreadcrumb(crumb1)
        
        let crumb2 = TestData.crumb
        crumb2.message = "Crumb 2"
        scope.addBreadcrumb(crumb2)
        
        return scope
    }
    
    static var userFeedback: UserFeedback {
        let userFeedback = UserFeedback(eventId: SentryId())
        userFeedback.comments = "It doesn't really"
        userFeedback.email = "john@me.com"
        userFeedback.name = "John Me"
        return userFeedback
    }
    
    static func setContext(_ scope: Scope) {
        scope.setContext(value: TestData.context["context"]!, key: "context")
    }
    
    static var request: SentryRequest {
        let request = SentryRequest()
        request.url = "https://sentry.io"
        request.fragment = "fragment"
        request.bodySize = 10
        request.queryString = "query"
        request.cookies = "cookies"
        request.method = "GET"
        request.headers = ["header": "value"]
        
        return request
    }

    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    static func getAppStartMeasurement(type: SentryAppStartType, appStartTimestamp: Date = TestData.timestamp, runtimeInitSystemTimestamp: UInt64) -> SentryAppStartMeasurement {
        let appStartDuration = 0.5
        let main = appStartTimestamp.addingTimeInterval(0.15)
        let runtimeInit = appStartTimestamp.addingTimeInterval(0.05)
        let sdkStart = appStartTimestamp.addingTimeInterval(0.1)
        let didFinishLaunching = appStartTimestamp.addingTimeInterval(0.2)
        
        return SentryAppStartMeasurement(type: type, isPreWarmed: false, appStartTimestamp: appStartTimestamp, runtimeInitSystemTimestamp: runtimeInitSystemTimestamp, duration: appStartDuration, runtimeInitTimestamp: runtimeInit, moduleInitializationTimestamp: main, sdkStartTimestamp: sdkStart, didFinishLaunchingTimestamp: didFinishLaunching)
    }

    #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
}
