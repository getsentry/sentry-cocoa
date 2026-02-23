// swiftlint:disable file_length
/// Configuration options for the Sentry SDK.
@objc(SentryOptions) public final class Options: NSObject {
    
    @objc public override init() {
        super.init()
        #if os(macOS)
        if let dsn = ProcessInfo.processInfo.environment["SENTRY_DSN"], dsn.count > 0 {
            do {
                self.parsedDsn = try SentryDsn(string: dsn)
                self.dsn = dsn
            } catch {
                self.parsedDsn = nil
                self.dsn = nil
            }
        }
        #endif
    }
    
    /// The DSN tells the SDK where to send the events to. If this value is not provided, the SDK will
    /// not send any events.
    @objc public var dsn: String? {
        didSet {
            do {
                self.parsedDsn = try SentryDsn(string: dsn)
            } catch {
                self.parsedDsn = nil
                self.dsn = nil
                SentrySDKLog.error("Could not parse the DSN: \(error)")
            }
        }
    }

    /// The parsed internal DSN.
    @objc public var parsedDsn: SentryDsn?

    /// Turns debug mode on or off. If debug is enabled SDK will attempt to print out useful debugging
    /// information if something goes wrong.
    /// @note Default is @c false.
    @objc public var debug: Bool = false

    /// Minimum LogLevel to be used if debug is enabled.
    /// @note Default is kSentryLevelDebug.
    @objc public var diagnosticLevel: SentryLevel = .debug

    /// This property will be filled before the event is sent.
    @objc public var releaseName: String? = {
        guard let infoDict = Bundle.main.infoDictionary else { return nil }

        return "\(infoDict["CFBundleIdentifier"] ?? "")@\(infoDict["CFBundleShortVersionString"] ?? "")+\(infoDict["CFBundleVersion"] ?? "")"
    }()

    /// The distribution of the application.
    /// @discussion Distributions are used to disambiguate build or deployment variants of the same
    /// release of an application. For example, the dist can be the build number of an Xcode build.
    @objc public var dist: String?

    /// The environment used for events if no environment is set on the current scope.
    /// @note Default value is "production".
    @objc public var environment: String = Options.defaultEnvironment

    /// Specifies whether this SDK should send events to Sentry. If set to @c false events will be
    /// dropped in the client and not sent to Sentry. Default is @c true.
    @objc public var enabled = true

    /// Controls the flush duration when calling SentrySDK/close.
    @objc public var shutdownTimeInterval: TimeInterval = 2.0

    /// When enabled, the SDK sends crashes to Sentry.
    /// @note Disabling this feature disables the SentryWatchdogTerminationTrackingIntegration,
    /// because SentryWatchdogTerminationTrackingIntegration would falsely report every crash as watchdog
    /// termination.
    /// @note Default value is @c true.
    /// @note Crash reporting is automatically disabled if a debugger is attached.
    @objc public var enableCrashHandler: Bool = true

    #if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
    /// When enabled, the SDK captures uncaught NSExceptions. As this feature uses swizzling, disabling
    /// enableSwizzling also disables this feature.
    ///
    /// @discussion This option registers the `NSApplicationCrashOnExceptions` UserDefault,
    /// so your macOS application crashes when an uncaught exception occurs. As the Cocoa Frameworks are
    /// generally not exception-safe on macOS, we recommend this approach because the application could
    /// otherwise end up in a corrupted state.
    ///
    /// @warning Don't use this in combination with `SentryCrashExceptionApplication`. Either enable this
    /// feature or use the `SentryCrashExceptionApplication`. Having both enabled can lead to duplicated
    /// reports.
    ///
    /// @note Default value is @c false.
    @objc public var enableUncaughtNSExceptionReporting: Bool = false
    #endif

    #if !os(watchOS)
    /// When enabled, the SDK reports SIGTERM signals to Sentry.
    ///
    /// It's crucial for developers to understand that the OS sends a SIGTERM to their app as a prelude
    /// to a graceful shutdown, before resorting to a SIGKILL. This SIGKILL, which your app can't catch
    /// or ignore, is a direct order to terminate your app's process immediately. Developers should be
    /// aware that their app can receive a SIGTERM in various scenarios, such as CPU or disk overuse,
    /// watchdog terminations, or when the OS updates your app.
    ///
    /// @note The default value is @c false.
    @objc public var enableSigtermReporting: Bool = false
    #endif

    /// How many breadcrumbs do you want to keep in memory?
    /// @note Default is 100.
    @objc public var maxBreadcrumbs: UInt = 100

    /// When enabled, the SDK adds breadcrumbs for each network request. As this feature uses swizzling,
    /// disabling enableSwizzling also disables this feature.
    /// @discussion If you want to enable or disable network tracking for performance monitoring, please
    /// use enableNetworkTracking instead.
    /// @note Default value is @c true.
    @objc public var enableNetworkBreadcrumbs: Bool = true

    /// The maximum number of envelopes to keep in cache.
    /// @note Default is 30.
    @objc public var maxCacheItems: UInt = 30

    /// This block can be used to modify the event before it will be serialized and sent.
    @objc public var beforeSend: SentryBeforeSendEventCallback?

    /// Use this callback to drop or modify a span before the SDK sends it to Sentry. Return nil to
    /// drop the span.
    @objc public var beforeSendSpan: SentryBeforeSendSpanCallback?

    /// When enabled, the SDK sends logs to Sentry. Logs can be captured using the SentrySDK.logger
    /// API, which provides structured logging with attributes.
    /// @note Default value is @c false.
    @objc public var enableLogs: Bool = false

    /// Use this callback to drop or modify a log before the SDK sends it to Sentry. Return nil to
    /// drop the log.
    @objc public var beforeSendLog: ((SentryLog) -> SentryLog?)?

    /// This block can be used to modify the breadcrumb before it will be serialized and sent.
    @objc public var beforeBreadcrumb: SentryBeforeBreadcrumbCallback?

    /// You can use this callback to decide if the SDK should capture a screenshot or not. Return @c true
    /// if the SDK should capture a screenshot, return @c false if not. This callback doesn't work for
    /// crashes.
    @objc public var beforeCaptureScreenshot: SentryBeforeCaptureScreenshotCallback?

    /// You can use this callback to decide if the SDK should capture a view hierarchy or not. Return
    /// @c true if the SDK should capture a view hierarchy, return @c false if not. This callback doesn't
    /// work for crashes.
    @objc public var beforeCaptureViewHierarchy: SentryBeforeCaptureScreenshotCallback?

    /// A block called shortly after the initialization of the SDK when the last program execution
    /// terminated with a crash.
    /// @discussion This callback is only executed once during the entire run of the program to avoid
    /// multiple callbacks if there are multiple crash events to send. This can happen when the program
    /// terminates with a crash before the SDK can send the crash event. You can look into beforeSend
    /// if you prefer a callback for every event.
    /// @warning It is not guaranteed that this is called on the main thread.
    /// @note Crash reporting is automatically disabled if a debugger is attached.
    @available(*, deprecated, message: "Use onLastRunStatusDetermined instead, which is called regardless of whether the app crashed.")
    @objc public var onCrashedLastRun: SentryOnCrashedLastRunCallback?

    /// A block called shortly after the initialization of the SDK when the crash status of the
    /// last program execution has been determined.
    ///
    /// This callback is invoked regardless of whether the app crashed or not:
    /// - If the last run ended with a crash, `status` is ``SentryLastRunStatus/didCrash`` and
    ///   `crashEvent` contains the crash event.
    /// - If the last run did **not** end with a crash, `status` is
    ///   ``SentryLastRunStatus/didNotCrash`` and `crashEvent` is `nil`.
    ///
    /// This callback is only executed once during the entire run of the program.
    ///
    /// - warning: It is not guaranteed that this is called on the main thread.
    /// - note: Crashes that occur while a debugger is attached are not recorded.
    ///   In that case, the callback reports ``SentryLastRunStatus/didNotCrash``
    ///   even though the app did crash.
    @objc public var onLastRunStatusDetermined: ((SentryLastRunStatus, Event?) -> Void)?

    /// Indicates the percentage of events being sent to Sentry.
    /// @discussion Specifying 0 discards all events, 1.0 or nil sends all events, 0.01 collects 1% of
    /// all events.
    /// @note The value needs to be >= 0.0 and <= 1.0. When setting a value out of range the SDK sets
    /// it to the default of 1.0.
    /// @note The default is 1.
    @objc public var sampleRate: NSNumber? {
        set {
            guard let newValue else {
                _sampleRate = nil
                return
            }
            if newValue.isValidSampleRate() {
                _sampleRate = newValue
            } else {
                _sampleRate = 1
            }
        }
        get {
            _sampleRate
        }
    }
    var _sampleRate: NSNumber? = 1

    /// Whether to enable automatic session tracking or not.
    /// @note Default is @c true.
    @objc public var enableAutoSessionTracking: Bool = true

    /// Whether to attach the top level `operationName` node of HTTP json requests to HTTP breadcrumbs
    /// @note Default is @c false.
    @objc public var enableGraphQLOperationTracking: Bool = false

    /// Whether to enable Watchdog Termination tracking or not.
    /// @note This feature requires the SentryCrashIntegration being enabled, otherwise it would
    /// falsely report every crash as watchdog termination.
    /// @note Default is @c true.
    @objc public var enableWatchdogTerminationTracking: Bool = true

    /// The interval to end a session after the App goes to the background.
    /// @note The default is 30 seconds.
    @objc public var sessionTrackingIntervalMillis: UInt = 30_000

    /// When enabled, stack traces are automatically attached to all messages logged. Stack traces are
    /// always attached to exceptions but when this is set stack traces are also sent with messages.
    /// Stack traces are only attached for the current thread.
    /// @note This feature is enabled by default.
    @objc public var attachStacktrace: Bool = true

    /// The maximum size for each attachment in bytes.
    /// @note Default is 200 MiB (200 ✕ 1024 ✕ 1024 bytes).
    /// @note Please also check the maximum attachment size of relay to make sure your attachments don't
    /// get discarded there:
    ///  https://docs.sentry.io/product/relay/options/
    @objc public var maxAttachmentSize: UInt = 200 * 1_024 * 1_024

    /// When enabled, the SDK sends personal identifiable along with events.
    /// @note The default is @c false.
    /// @discussion When the user of an event doesn't contain an IP address, and this flag is @c true, the
    /// SDK sets sdk.settings.infer_ip to auto to instruct the server to use the connection IP address as
    /// the user address. Due to backward compatibility concerns, Sentry sets sdk.settings.infer_ip to
    /// auto out of the box for Cocoa. If you want to stop Sentry from using the connections IP address,
    /// you have to enable Prevent Storing of IP Addresses in your project settings in Sentry.
    @objc public var sendDefaultPii: Bool = false

    /// When enabled, the SDK tracks performance for UIViewController subclasses and HTTP requests
    /// automatically. It also measures the app start and slow and frozen frames.
    /// @note The default is @c true.
    /// @note Performance Monitoring must be enabled for this flag to take effect. See:
    /// https://docs.sentry.io/platforms/apple/performance/
    @objc public var enableAutoPerformanceTracing: Bool = true

    /// WARNING: This is an experimental feature and may still have bugs.
    ///
    /// When enabled, the SDK finishes the ongoing transaction bound to the scope and links them to the
    /// crash event when your app crashes. The SDK skips adding profiles to increase the chance of
    /// keeping the transaction.
    ///
    /// @note The default is @c false.
    @objc public var enablePersistingTracesWhenCrashing: Bool = false

    /// A block that configures the initial scope when starting the SDK.
    /// @discussion The block receives a suggested default scope. You can either configure and return
    /// this, or create your own scope instead.
    /// @note The default simply returns the passed in scope.
    @objc public var initialScope: ((Scope) -> Scope) = { return $0 }
    
    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

    /// When enabled, the SDK tracks performance for UIViewController subclasses.
    /// @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
    /// configurations even when targeting iOS or tvOS platforms.
    /// @note The default is @c true.
    @objc public var enableUIViewControllerTracing: Bool = true

    /// Automatically attaches a screenshot when capturing an error or exception.
    /// @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
    /// configurations even when targeting iOS or tvOS platforms.
    /// @note Default value is @c false.
    @objc public var attachScreenshot: Bool = false

    /// Settings to configure screenshot attachments.
    @objc public var screenshot: SentryViewScreenshotOptions = SentryViewScreenshotOptions()

    /// @warning This is an experimental feature and may still have bugs.
    /// @brief Automatically attaches a textual representation of the view hierarchy when capturing an
    /// error event.
    /// @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
    /// configurations even when targeting iOS or tvOS platforms.
    /// @note Default value is @c false.
    @objc public var attachViewHierarchy: Bool = false

    /// @brief If enabled, view hierarchy attachment will contain view `accessibilityIdentifier`.
    /// Set it to @c false if your project uses `accessibilityIdentifier` for PII.
    /// @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
    /// configurations even when targeting iOS or tvOS platforms.
    /// @note Default value is @c true.
    @objc public var reportAccessibilityIdentifier: Bool = true

    /// When enabled, the SDK creates transactions for UI events like buttons clicks, switch toggles,
    /// and other ui elements that uses UIControl @c sendAction:to:forEvent:
    /// @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
    /// configurations even when targeting iOS or tvOS platforms.
    /// @note Default value is @c true.
    @objc public var enableUserInteractionTracing: Bool = true

    /// How long an idle transaction waits for new children after all its child spans finished. Only UI
    /// event transactions are idle transactions.
    /// @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
    /// configurations even when targeting iOS or tvOS platforms.
    /// @note The default is 3 seconds.
    @objc public var idleTimeout: TimeInterval = 3.0

    /// Report pre-warmed app starts by dropping the first app start spans if pre-warming paused
    /// during these steps. This approach will shorten the app start duration, but it represents the
    /// duration a user has to wait after clicking the app icon until the app is responsive.
    ///
    /// @note You can filter for different app start types in Discover with
    /// @c app_start_type:cold.prewarmed ,
    /// @c app_start_type:warm.prewarmed , @c app_start_type:cold , and @c app_start_type:warm .
    ///
    /// @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
    /// configurations even when targeting iOS or tvOS platforms.
    ///
    /// @note Default value is @c true.
    @objc public var enablePreWarmedAppStartTracing: Bool = true
    
    /// When enabled the SDK reports non-fully-blocking app hangs. A non-fully-blocking app hang is when
    /// the app appears stuck to the user but can still render a few frames.
    ///
    /// @note The default is @c true.
    @objc public var enableReportNonFullyBlockingAppHangs: Bool = true
    
    // swiftlint:disable:next missing_docs
    @_spi(Private) @objc public func isAppHangTrackingDisabled() -> Bool {
        !enableAppHangTracking || appHangTimeoutInterval <= 0
    }
    
    #endif
    
    #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    
    /// Configuration options for Session Replay.
    @objc public var sessionReplay = SentryReplayOptions()

    #endif
    
    /// When enabled, the SDK tracks performance for HTTP requests if auto performance tracking and
    /// @c enableSwizzling are enabled.
    /// @note The default is @c true.
    /// @discussion If you want to enable or disable network breadcrumbs, please use
    /// @c enableNetworkBreadcrumbs instead.
    @objc public var enableNetworkTracking: Bool = true

    /// When enabled, the SDK tracks performance for file IO reads and writes with NSData if auto
    /// performance tracking and enableSwizzling are enabled.
    /// @note The default is @c true.
    @objc public var enableFileIOTracing: Bool = true

    /// When enabled, the SDK tracks performance for file IO reads and writes with NSData if auto
    /// performance tracking and enableSwizzling are enabled.
    /// @note The default is @c true.
    @objc public var enableDataSwizzling: Bool = true

    /// When enabled, the SDK tracks performance for file IO operations with NSFileManager if auto
    /// performance tracking and enableSwizzling are enabled.
    /// @note The default is @c false.
    @objc public var enableFileManagerSwizzling: Bool = false

    /// Indicates the percentage of the tracing data that is collected.
    /// @discussion Specifying @c 0 or @c nil discards all trace data, @c 1.0 collects all trace data,
    /// @c 0.01 collects 1% of all trace data.
    /// @note The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
    /// to the default.
    /// @note The default is @c 0 .
    @objc public var tracesSampleRate: NSNumber? {
        set {
            guard let newValue else {
                _tracesSampleRate = nil
                return
            }
            if newValue.isValidSampleRate() {
                _tracesSampleRate = newValue
            } else {
                _tracesSampleRate = 0
            }
        }
        get {
            _tracesSampleRate
        }
    }
    var _tracesSampleRate: NSNumber?

    /// A callback to a user defined traces sampler function.
    /// @discussion Specifying @c 0 or @c nil discards all trace data, @c 1.0 collects all trace data,
    /// @c 0.01 collects 1% of all trace data.
    /// @note The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
    /// to the default of @c 0 .
    @objc public var tracesSampler: SentryTracesSamplerCallback?

    /// If tracing is enabled or not.
    /// @discussion @c true if @c tracesSampleRate is > @c 0 and \<= @c 1
    /// or a @c tracesSampler is set, otherwise @c false.
    @objc public var isTracingEnabled: Bool {
        (tracesSampleRate?.doubleValue ?? 0) > 0 && (tracesSampleRate?.doubleValue ?? 0) <= 1 || tracesSampler != nil
    }

    /// A list of string prefixes of framework names that belong to the app.
    /// @note By default, this contains @c CFBundleExecutable to mark it as "in-app".
    @objc public private(set) var inAppIncludes: [String] = {
        if let executable = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String {
            return [executable]
        }
        return []
    }()
    
    /// Adds an item to the list of inAppIncludes.
    /// - Parameter inAppInclude: The prefix of the framework name.
    @objc public func add(inAppInclude: String) {
        inAppIncludes.append(inAppInclude)
    }

    /// Set as delegate on the URLSession used for all network data-transfer tasks performed by Sentry.
    /// The SDK ignores this option when using urlSession.
    @objc public weak var urlSessionDelegate: URLSessionDelegate?

    /// Use this property so the transport uses this URLSession with your configuration for
    /// sending requests to Sentry. If not set, the SDK will create a new URLSession with
    /// URLSessionConfiguration.ephemeral.
    @objc public var urlSession: URLSession?

    /// Whether the SDK should use swizzling or not.
    /// When turned off the following features are disabled: breadcrumbs for touch events and
    /// navigation with UIViewControllers, automatic instrumentation for UIViewControllers,
    /// automatic instrumentation for HTTP requests, automatic instrumentation for file IO with
    /// NSData, and automatically added sentry-trace header to HTTP requests for distributed tracing.
    /// Default is @c true.
    @objc public var enableSwizzling: Bool = true

    /// A set of class names to ignore for swizzling.
    /// The SDK checks if a class name of a class to swizzle contains a class name of this array.
    /// For example, if you add MyUIViewController to this list, the SDK excludes the following classes
    /// from swizzling: YourApp.MyUIViewController, YourApp.MyUIViewControllerA, MyApp.MyUIViewController.
    /// Default is an empty set.
    @objc public var swizzleClassNameExcludes: Set<String> = []

    /// When enabled, the SDK tracks the performance of Core Data operations. It requires enabling
    /// performance monitoring. The default is @c true.
    /// See: https://docs.sentry.io/platforms/apple/performance/
    @objc public var enableCoreDataTracing: Bool = true
    
#if !(os(watchOS) || os(tvOS) || os(visionOS))

    /// Configuration for the Sentry profiler.
    /// @warning: Continuous profiling is an experimental feature and may still contain bugs.
    /// @warning: Profiling is automatically disabled if a thread sanitizer is attached.
    @objc public var configureProfiling: ((SentryProfileOptions) -> Void)? {
        didSet {
            let profiling = SentryProfileOptions()
            if let configureProfiling {
                configureProfiling(profiling)
                self.profiling = profiling
            } else {
                self.profiling = nil
            }
        }
    }

    // swiftlint:disable:next missing_docs
    @_spi(Private) @objc public var profiling: SentryProfileOptions?
    
    // swiftlint:disable:next missing_docs
    @_spi(Private) @objc public func isContinuousProfilingEnabled() -> Bool {
        profiling != nil
    }

    // swiftlint:disable:next missing_docs
    @_spi(Private) @objc public func isProfilingCorrelatedToTraces() -> Bool {
        profiling?.lifecycle == .trace
    }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
    
    /// Whether to send client reports, which contain statistics about discarded events.
    /// @note The default is @c true.
    /// @see <https://develop.sentry.dev/sdk/client-reports/>
    @objc public var sendClientReports: Bool = true

    /// When enabled, the SDK tracks when the application stops responding for a specific amount of
    /// time defined by the @c appHangTimeoutInterval option.
    ///
    /// On iOS, tvOS and visionOS, the SDK can differentiate between fully-blocking and non-fully
    /// blocking app hangs. Important: this feature can't differentiate between fully-blocking and
    /// non-fully-blocking app hangs on macOS.
    ///
    /// A fully-blocking app hang is when the main thread is stuck completely, and the app can't render a
    /// single frame. A non-fully-blocking app hang is when the app appears stuck to the user but can still
    /// render a few frames. Fully-blocking app hangs are more actionable because the stacktrace shows the
    /// exact blocking location on the main thread. As the main thread isn't completely blocked,
    /// non-fully-blocking app hangs can have a stacktrace that doesn't highlight the exact blocking
    /// location.
    ///
    /// You can use @c enableReportNonFullyBlockingAppHangs to ignore non-fully-blocking app hangs.
    ///
    /// @note The default is @c true.
    /// @note App Hang tracking is automatically disabled if a debugger is attached.
    @objc public var enableAppHangTracking: Bool = true

    /// The minimum amount of time an app should be unresponsive to be classified as an App Hanging.
    /// @note The actual amount may be a little longer.
    /// @note Avoid using values lower than 100ms, which may cause a lot of app hangs events being
    /// transmitted.
    /// @note The default value is 2 seconds.
    @objc public var appHangTimeoutInterval: TimeInterval = 2.0

    /// When enabled, the SDK adds breadcrumbs for various system events.
    /// @note Default value is @c true.
    @objc public var enableAutoBreadcrumbTracking: Bool = true

    /// When enabled, the SDK propagates the W3C Trace Context HTTP header traceparent on outgoing HTTP
    /// requests.
    ///
    /// @discussion This is useful when the receiving services only support OTel/W3C propagation. The
    /// traceparent header is only sent when this option is @c true and the request matches @c
    /// tracePropagationTargets.
    ///
    /// @note Default value is @c false.
    @objc public var enablePropagateTraceparent: Bool = false
    
    static let everythingAllowedRegex = try? NSRegularExpression(pattern: ".*", options: .caseInsensitive)

    /// An array of hosts or regexes that determines if outgoing HTTP requests will get
    /// extra @c trace_id and @c baggage headers added.
    /// @discussion This array can contain instances of @c NSString which should match the URL (using
    /// @c contains ), and instances of @c NSRegularExpression, which will be used to check the whole
    /// URL.
    /// @note The default value adds the header to all outgoing requests.
    /// @see https://docs.sentry.io/platforms/apple/configuration/options/#trace-propagation-targets
    @objc public var tracePropagationTargets: [Any] = [everythingAllowedRegex as Any] {
        didSet {
            for value in tracePropagationTargets {
                if !(value is NSRegularExpression || value is String) {
                    SentrySDKLog.warning("Only instances of NSString and NSRegularExpression are supported inside tracePropagationTargets.")
                }
            }
        }
    }

    /// When enabled, the SDK captures HTTP Client errors.
    /// @note This feature requires @c enableSwizzling enabled as well.
    /// @note Default value is @c true.
    @objc public var enableCaptureFailedRequests: Bool = true

    /// The SDK will only capture HTTP Client errors if the HTTP Response status code is within the
    /// defined range.
    /// @note Defaults to 500 - 599.
    ///         SentryHttpStatusCodeRange *defaultHttpStatusCodeRange =
    @objc public var failedRequestStatusCodes: [HttpStatusCodeRange] = [HttpStatusCodeRange(min: 500, max: 599)]

    /// An array of hosts or regexes that determines if HTTP Client errors will be automatically
    /// captured.
    /// @discussion This array can contain instances of @c NSString which should match the URL (using
    /// @c contains ), and instances of @c NSRegularExpression, which will be used to check the whole
    /// URL.
    /// @note The default value automatically captures HTTP Client errors of all outgoing requests.
    @objc public var failedRequestTargets: [Any] = [everythingAllowedRegex as Any] {
        didSet {
            for value in failedRequestTargets {
                if !(value is NSRegularExpression || value is String) {
                    SentrySDKLog.warning("Only instances of NSString and NSRegularExpression are supported inside failedRequestTargets.")
                }
            }
        }
    }
    
    #if canImport(MetricKit) && !os(tvOS)
    
    /// Use this feature to enable the Sentry MetricKit integration.
    ///
    /// @brief When enabled, the SDK sends @c MXDiskWriteExceptionDiagnostic, @c MXCPUExceptionDiagnostic
    /// and
    /// @c MXHangDiagnostic to Sentry. The SDK supports this feature from iOS 15 and later and macOS 12
    /// and later because, on these versions, @c MetricKit delivers diagnostic reports immediately, which
    /// allows the Sentry SDK to apply the current data from the scope.
    /// @note This feature is disabled by default.
    @objc public var enableMetricKit = false
    
    /// When enabled, the SDK adds the raw MXDiagnosticPayloads as an attachment to the converted
    /// SentryEvent. You need to enable @c enableMetricKit for this flag to work.
    ///
    /// @note Default value is @c false.
    @objc public var enableMetricKitRawPayload = false
    
    #endif
    
    /// @warning This is an experimental feature and may still have bugs.
    /// @brief By enabling this, every UIViewController tracing transaction will wait
    /// for a call to @c SentrySDK.reportFullyDisplayed().
    /// @discussion Use this in conjunction with @c enableUIViewControllerTracing.
    /// If @c SentrySDK.reportFullyDisplayed() is not called, the transaction will finish
    /// automatically after 30 seconds and the `Time to full display` Span will be
    /// finished with @c DeadlineExceeded status.
    /// @note Default value is `false`.
    @objc public var enableTimeToFullDisplayTracing: Bool = false

    /// This feature is only available from Xcode 13 and from macOS 12.0, iOS 15.0, tvOS 15.0,
    /// watchOS 8.0.
    ///
    /// @warning This is an experimental feature and may still have bugs.
    /// @brief Stitches the call to Swift Async functions in one consecutive stack trace.
    /// @note Default value is @c false.
    @objc public var swiftAsyncStacktraces: Bool = false

    /// The path to store SDK data, like events, transactions, profiles, raw crash data, etc. We
    /// recommend only changing this when the default, e.g., in security environments, can't be accessed.
    ///
    /// @note The default is `NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask,
    /// true)`.
    @objc public var cacheDirectoryPath: String = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? ""

    /// Whether to enable Spotlight for local development. For more information see
    /// https://spotlightjs.com/.
    ///
    /// @note Only set this option to @c true while developing, not in production!
    @objc public var enableSpotlight: Bool = false {
        didSet {
            #if !DEBUG
            if enableSpotlight {
                SentrySDKLog.warning("Enabling Spotlight for a release build. We recommend running Spotlight only for local development.")
            }
            #endif
        }
    }

    /// The Spotlight URL. Defaults to http://localhost:8969/stream. For more information see
    /// https://spotlightjs.com/
    @objc public var spotlightUrl = "http://localhost:8969/stream"

    /// Options for experimental features that are subject to change.
    @objc public var experimental = SentryExperimentalOptions()
    
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    
    // swiftlint:disable:next missing_docs
    @_spi(Private) @objc public var userFeedbackConfiguration: SentryUserFeedbackConfiguration?
    
    /// A block that configures the user feedback feature.
    @available(iOSApplicationExtension, unavailable)
    @objc public var configureUserFeedback: ((SentryUserFeedbackConfiguration) -> Void)? {
        didSet {
            let config = SentryUserFeedbackConfiguration()
            configureUserFeedback?(config)
            userFeedbackConfiguration = config
        }
    }
    #endif
    
    // swiftlint:disable:next missing_docs
    @_spi(Private) @objc public static func isValidSampleRate(_ rate: NSNumber) -> Bool {
        rate.isValidSampleRate()
    }
    
    // swiftlint:disable:next missing_docs
    @_spi(Private) @objc public static let defaultEnvironment = "production"
}

extension NSNumber {
    func isValidSampleRate() -> Bool {
        doubleValue >= 0 && doubleValue <= 1.0
    }
}

// swiftlint:enable file_length
