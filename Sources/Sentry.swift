//
//  Sentry.swift
//  Sentry
//
//  Created by Josh Holtz on 12/16/15.
//
//

import Foundation
import KSCrash

#if swift(>=3.0)
    public typealias AnyType = Any
#else
    public typealias AnyType = AnyObject
    internal typealias Error = ErrorType
    internal typealias ProcessInfo = NSProcessInfo
    internal typealias JSONSerialization = NSJSONSerialization
    internal typealias Bundle = NSBundle
    internal typealias URLQueryItem = NSURLQueryItem
    internal typealias URLSession = NSURLSession
    internal typealias URLRequest = NSURLRequest
    internal typealias OperationQueue = NSOperationQueue
    internal typealias Operation = NSOperation
    internal typealias URLSessionTask = NSURLSessionTask
    internal typealias URL = NSURL
    internal typealias URLComponents = NSURLComponents
    internal typealias Data = NSData
    internal typealias TimeInterval = NSTimeInterval
    internal typealias Date = NSDate
#endif

@objc public class SentryClient: NSObject, EventProperties {
    
    // MARK: - Static Attributes
    
    public static var shared: SentryClient?
    public static var logLevel: Log = .Error
    
    public static var versionString: String {
        return "\(Info.version) (\(Info.sentryVersion))"
    }
    
    internal static let queueName = "io.sentry.event.queue"
    
    // MARK: - Enums
    
    internal struct Info {
        static let version: String = "2.1.6"
        static let sentryVersion: Int = 7
    }
    
    internal struct CrashLanguages {
        static let reactNative = "react-native"
    }
    
    // MARK: - Attributes
    
    internal let dsn: DSN
    internal let requestManager: RequestManager
    internal(set) var crashHandler: CrashHandler? {
        didSet {
            crashHandler?.startCrashReporting()
            crashHandler?.releaseVersion = releaseVersion
            crashHandler?.buildNumber = buildNumber
            crashHandler?.tags = tags
            crashHandler?.extra = extra
            crashHandler?.user = user
        }
    }
    
    public lazy var breadcrumbs: BreadcrumbStore = {
        let store = BreadcrumbStore()
        store.storeUpdated = {
            self.crashHandler?.breadcrumbsSerialized = $0.serialized
        }
        return store
    }()
    
    internal var stacktraceSnapshot: Event.StacktraceSnapshot?
    
    // MARK: UserFeedback
    #if os(iOS)
    internal var userFeedbackViewControllers: UserFeedbackViewContollers?
    
    public weak var delegate: SentryClientUserFeedbackDelegate?
    internal(set) var userFeedbackViewModel: UserFeedbackViewModel?
    internal(set) var lastSuccessfullySentEvent: Event? {
        didSet {
            guard nil != lastSuccessfullySentEvent else {
                return
            }
            #if swift(>=3.0)
                DispatchQueue.main.async {
                    self.delegate?.userFeedbackReady()
                }
            #else
                dispatch_async(dispatch_get_main_queue(), {
                    self.delegate?.userFeedbackReady()
                })
            #endif
        }
    }
    #endif
    // ------------------
    // MARK: EventProperties
    public var releaseVersion: String? {
        didSet { crashHandler?.releaseVersion = releaseVersion }
    }
    public var buildNumber: String? {
        didSet { crashHandler?.buildNumber = buildNumber }
    }
    public var tags: EventTags = [:] {
        didSet { crashHandler?.tags = tags }
    }
    private var _extra: EventExtra = [:] {
        didSet { crashHandler?.extra = _extra }
    }
    public var extra: EventExtra {
        get { return _extra }
        set {
            _extra = (sanitize(newValue) as? EventExtra) ?? [:]
        }
    }
    public var user: User? = nil {
        didSet { crashHandler?.user = user }
    }
    // ------------------
    
    public typealias ObjcEventBeforeSend = (UnsafeMutablePointer<Event>) -> Void
    public typealias EventBeforeSend = (inout Event) -> Void
    /// Use this block to get the event that will be send with the next
    @objc public var objcBeforeSendEventBlock: ObjcEventBeforeSend?
    public var beforeSendEventBlock: EventBeforeSend?
    
    /// Creates a Sentry object to use for reporting
    internal init(dsn: DSN, requestManager: RequestManager) {
        self.dsn = dsn
        self.requestManager = requestManager
        
        #if swift(>=3.0)
            self.releaseVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        #else
            self.releaseVersion = NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as? String
            self.buildNumber = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as? String
        #endif
        
        super.init()
        sendEventsOnDiskInBackground()
    }
    
    convenience init(dsn: DSN) {
        #if swift(>=3.0)
            let requestManager = QueueableRequestManager(session: URLSession(configuration: URLSessionConfiguration.ephemeral))
        #else
            let requestManager = QueueableRequestManager(session: NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration()))
        #endif
        self.init(dsn: dsn, requestManager: requestManager)
    }
    
    /// Creates a Sentry object if a valid DSN is provided
    @objc public convenience init?(dsnString: String) {
        // Silently not creating a client if dsnString is empty string
        if dsnString.isEmpty {
            Log.Debug.log("DSN provided was empty - not creating a SentryClient object")
            return nil
        }
        
        // Try to create a client with a DSN string
        // Log error if cannot make one
        do {
            let dsn = try DSN(dsnString)
            self.init(dsn: dsn)
        } catch {
            Log.Error.log("DSN is invalid")
            return nil
        }
    }
    
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
    
    #if os(iOS)
    @objc public func enableAutomaticBreadcrumbTracking() {
        SentrySwizzle.enableAutomaticBreadcrumbTracking()
    }
    #endif
    
    /// This will make you app crash, use only for test purposes
    @objc public func crash() {
        fatalError("TEST - Sentry Client Crash")
    }
}
