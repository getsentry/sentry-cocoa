// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

// This provides the public API for passing what is essentially a `SentryCrashReportFilter` to Swift.
@_spi(Private) @objc public final class SentryCrashReportFilterSwift: NSObject {
    
    fileprivate let filter: ([Any], @escaping ([Any]?, Bool, Error?) -> Void) -> Void

    @objc public init(filterReports filter: @escaping ([Any], @escaping ([Any]?, Bool, Error?) -> Void) -> Void) {
        self.filter = filter
    }
}

// This class converts from the Swift type `SentryCrashReportFilterSwift` to the ObjC protocol `SentryCrashReportFilter`.
private final class CrashReportFilterBridge: NSObject, SentryCrashReportFilter {
    private let filter: SentryCrashReportFilterSwift
    init(filter: SentryCrashReportFilterSwift) {
        self.filter = filter
    }

    func filterReports(_ reports: [Any], onCompletion: @escaping SentryCrashReportFilterCompletion) {
        filter.filter(reports, onCompletion)
    }
    
}

@_spi(Private) @objc public final class SentryCrashSwift: NSObject {
    
    private let sentryCrash: SentryCrash
    
    init(with basePath: String?) {
        sentryCrash = SentryCrash(basePath: basePath)
    }
    
    @objc public var crashedLastLaunch: Bool {
        sentryCrash.crashedLastLaunch
    }
    
    @objc public var activeDurationSinceLastCrash: TimeInterval {
        sentryCrash.activeDurationSinceLastCrash
    }
    
    @objc public func setSink(_ newValue: SentryCrashReportFilterSwift?) {
        if let newValue {
          sentryCrash.sink = CrashReportFilterBridge(filter: newValue)
        } else {
          sentryCrash.sink = nil
        }
    }
    
    @objc public func setupOnCrash() {
        sentryCrash.onCrash = sentry_crashCallback
    }
    
    @objc public func removeOnCrash() {
        sentryCrash.onCrash = nil
    }
    
    @objc public var uncaughtExceptionHandler: (@convention(c) (NSException) -> Void)? {
        get { sentryCrash.uncaughtExceptionHandler }
        set { sentryCrash.uncaughtExceptionHandler = newValue }
    }

    @objc public func setBridge(_ bridge: SentryCrashBridge) {
        sentryCrash.setValue(bridge, forKey: "bridge")
    }

    @objc public var basePath: String {
        get { sentryCrash.basePath }
        set { sentryCrash.basePath = newValue }
    }
    
    @objc public func install() {
        sentryCrash.install()
    }
    
    @objc public func uninstall() {
        sentryCrash.uninstall()
    }
    
    @objc public var systemInfo: [AnyHashable: Any]? {
        sentryCrash.systemInfo
    }
    
    @objc public var userInfo: [AnyHashable: Any] {
        get { sentryCrash.userInfo ?? [:] }
        set { sentryCrash.userInfo = newValue }
    }
    
    @objc public func sendAllReports(completion: @escaping ([Any]?, Bool, (any Error)?) -> Void) {
        sentryCrash.sendAllReports(completion: completion)
    }

    // Only visible for testing
    @objc public var monitoring: UInt32 {
        sentryCrash.monitoring.rawValue
    }

    @objc public func hasOnCrash() -> Bool {
        sentryCrash.onCrash != nil
    }
}
// swiftlint:enable missing_docs
