// swiftlint:disable file_length
// swiftlint:disable sorted_imports
import Foundation
@_implementationOnly import _SentryPrivate

// Constants from SentryInternalDefines.h
private let SENTRY_DEFAULT_SAMPLE_RATE = NSNumber(value: 1.0)
private let SENTRY_DEFAULT_TRACES_SAMPLE_RATE = NSNumber(value: 0.0)
private let SENTRY_DEFAULT_PROFILES_SAMPLE_RATE = NSNumber(value: 0.0)

/**
 * The DSN tells the SDK where to send the events to. If this value is not provided, the SDK will
 * not send any events.
 */
@objc(SentryOptions)
@objcMembers
public class Options: NSObject {
    
    // MARK: - Properties
    
    /**
     * The DSN tells the SDK where to send the events to. If this value is not provided, the SDK will
     * not send any events.
     */
    public var dsn: String? {
        get {
            _dsn
        }
        set {
            do {
                self.parsedDsn = try SentryDsn(string: newValue ?? "")
            } catch {
                SentrySDKLog.error("Could not parse the DSN: \(error).")
                _dsn = nil
                parsedDsn = nil
            }
        }
    }
    private var _dsn: String?
    
    /**
     * The parsed internal DSN.
     */
    public var parsedDsn: SentryDsn?
    
    /**
     * Turns debug mode on or off. If debug is enabled SDK will attempt to print out useful debugging
     * information if something goes wrong.
     * @note Default is @c NO.
     */
    public var debug: Bool = false
    
    /**
     * Minimum LogLevel to be used if debug is enabled.
     * @note Default is @c kSentryLevelDebug.
     */
    public var diagnosticLevel: SentryLevel = .debug
    
    /**
     * This property will be filled before the event is sent.
     */
    public var releaseName: String?
    
    /**
     * The distribution of the application.
     * @discussion Distributions are used to disambiguate build or deployment variants of the same
     * release of an application. For example, the @c dist can be the build number of an Xcode build.
     */
    public var dist: String?
    
    /**
     * The environment used for events if no environment is set on the current scope.
     * @note Default value is @c @"production".
     */
    public var environment: String = "production"
    
    /**
     * Specifies wether this SDK should send events to Sentry. If set to @c NO events will be
     * dropped in the client and not sent to Sentry. Default is @c YES.
     */
    public var enabled: Bool = true
    
    /**
     * Controls the flush duration when calling @c SentrySDK/close .
     */
    public var shutdownTimeInterval: TimeInterval = 2.0
    
    /**
     * When enabled, the SDK sends crashes to Sentry.
     * @note Disabling this feature disables the @c SentryWatchdogTerminationTrackingIntegration ,
     * because
     * @c SentryWatchdogTerminationTrackingIntegration would falsely report every crash as watchdog
     * termination.
     * @note Default value is @c YES .
     * @note Crash reporting is automatically disabled if a debugger is attached.
     */
    public var enableCrashHandler: Bool = true
    
#if os(macOS)
    /**
     * When enabled, the SDK captures uncaught NSExceptions. As this feature uses swizzling, disabling
     * @c enableSwizzling also disables this feature.
     *
     * @discussion This option registers the `NSApplicationCrashOnExceptions` UserDefault,
     * so your macOS application crashes when an uncaught exception occurs. As the Cocoa Frameworks are
     * generally not exception-safe on macOS, we recommend this approach because the application could
     * otherwise end up in a corrupted state.
     *
     * @warning Don't use this in combination with `SentryCrashExceptionApplication`. Either enable this
     * feature or use the `SentryCrashExceptionApplication`. Having both enabled can lead to duplicated
     * reports.
     *
     * @note Default value is @c NO .
     */
    public var enableUncaughtNSExceptionReporting: Bool = false
#endif
    
#if !os(watchOS)
    /**
     * When enabled, the SDK reports SIGTERM signals to Sentry.
     *
     * It's crucial for developers to understand that the OS sends a SIGTERM to their app as a prelude
     * to a graceful shutdown, before resorting to a SIGKILL. This SIGKILL, which your app can't catch
     * or ignore, is a direct order to terminate your app's process immediately. Developers should be
     * aware that their app can receive a SIGTERM in various scenarios, such as  CPU or disk overuse,
     * watchdog terminations, or when the OS updates your app.
     *
     * @note The default value is @c NO.
     */
    public var enableSigtermReporting: Bool = false
#endif
    
    /**
     * How many breadcrumbs do you want to keep in memory?
     * @note Default is @c 100 .
     */
    public var maxBreadcrumbs: UInt = 100
    
    /**
     * When enabled, the SDK adds breadcrumbs for each network request. As this feature uses swizzling,
     * disabling @c enableSwizzling also disables this feature.
     * @discussion If you want to enable or disable network tracking for performance monitoring, please
     * use @c enableNetworkTracking instead.
     * @note Default value is @c YES .
     */
    public var enableNetworkBreadcrumbs: Bool = true
    
    /**
     * The maximum number of envelopes to keep in cache.
     * @note Default is @c 30 .
     */
    public var maxCacheItems: UInt = 30
    
    /**
     * This block can be used to modify the event before it will be serialized and sent.
     */
    public var beforeSend: SentryBeforeSendEventCallback?
    
    /**
     * Use this callback to drop or modify a span before the SDK sends it to Sentry. Return @c nil to
     * drop the span.
     */
    public var beforeSendSpan: SentryBeforeSendSpanCallback?
    
    /**
     * This block can be used to modify the event before it will be serialized and sent.
     */
    public var beforeBreadcrumb: SentryBeforeBreadcrumbCallback?
    
    /**
     * You can use this callback to decide if the SDK should capture a screenshot or not. Return @c true
     * if the SDK should capture a screenshot, return @c false if not. This callback doesn't work for
     * crashes.
     */
    public var beforeCaptureScreenshot: SentryBeforeCaptureScreenshotCallback?
    
    /**
     * You can use this callback to decide if the SDK should capture a view hierarchy or not. Return @c
     * true if the SDK should capture a view hierarchy, return @c false if not. This callback doesn't
     * work for crashes.
     */
    public var beforeCaptureViewHierarchy: SentryBeforeCaptureScreenshotCallback?
    
    /**
     * A block called shortly after the initialization of the SDK when the last program execution
     * terminated with a crash.
     * @discussion This callback is only executed once during the entire run of the program to avoid
     * multiple callbacks if there are multiple crash events to send. This can happen when the program
     * terminates with a crash before the SDK can send the crash event. You can look into @c beforeSend
     * if you prefer a callback for every event.
     * @warning It is not guaranteed that this is called on the main thread.
     * @note Crash reporting is automatically disabled if a debugger is attached.
     */
    public var onCrashedLastRun: SentryOnCrashedLastRunCallback?
    
    /**
     * Array of integrations to install.
     */
    public var integrations: [String]? {
        didSet {
            SentrySDKLog.warning("Setting `SentryOptions.integrations` is deprecated. Integrations should be enabled or disabled using their respective `SentryOptions.enable*` property.");
        }
    }
    
    public static var defaultIntegrations: [String] {
        // SentryOptionsInternal.defaultIntegrations()
        return []
    }
    
    /**
     * Indicates the percentage of events being sent to Sentry.
     * @discussion Specifying @c 0 discards all events, @c 1.0 or @c nil sends all events, @c 0.01
     * collects 1% of all events.
     * @note The value needs to be >= @c 0.0 and \<= @c 1.0. When setting a value out of range the SDK
     * sets it to the default of @c 1.0.
     * @note The default is @c 1 .
     */
    public var sampleRate: NSNumber? {
        didSet {
            if let sampleRate = sampleRate {
                if !sentry_isValidSampleRate(sampleRate) {
                    self.sampleRate = SENTRY_DEFAULT_SAMPLE_RATE
                }
            }
        }
    }
    
    /**
     * Whether to enable automatic session tracking or not.
     * @note Default is @c YES.
     */
    public var enableAutoSessionTracking: Bool = true
    
    /**
     * Whether to attach the top level `operationName` node of HTTP json requests to HTTP breadcrumbs
     * @note Default is @c NO.
     */
    public var enableGraphQLOperationTracking: Bool = false
    
    /**
     * Whether to enable Watchdog Termination tracking or not.
     * @note This feature requires the @c SentryCrashIntegration being enabled, otherwise it would
     * falsely report every crash as watchdog termination.
     * @note Default is @c YES.
     */
    public var enableWatchdogTerminationTracking: Bool = true
    
    /**
     * The interval to end a session after the App goes to the background.
     * @note The default is 30 seconds.
     */
    public var sessionTrackingIntervalMillis: UInt = 30_000
    
    /**
     * When enabled, stack traces are automatically attached to all messages logged. Stack traces are
     * always attached to exceptions but when this is set stack traces are also sent with messages.
     * Stack traces are only attached for the current thread.
     * @note This feature is enabled by default.
     */
    public var attachStacktrace: Bool = true
    
    /**
     * The maximum size for each attachment in bytes.
     * @note Default is 20 MiB (20 ✕ 1024 ✕ 1024 bytes).
     * @note Please also check the maximum attachment size of relay to make sure your attachments don't
     * get discarded there:
     *  https://docs.sentry.io/product/relay/options/
     */
    public var maxAttachmentSize: UInt = 20 * 1_024 * 1_024
    
    /**
     * When enabled, the SDK sends personal identifiable along with events.
     * @note The default is @c NO .
     * @discussion When the user of an event doesn't contain an IP address, and this flag is
     * @c YES, the SDK sets it to @c {{auto}} to instruct the server to use the
     * connection IP address as the user address. Due to backward compatibility concerns, Sentry set the
     * IP address to @c {{auto}} out of the box for Cocoa. If you want to stop Sentry from
     * using the connections IP address, you have to enable Prevent Storing of IP Addresses in your
     * project settings in Sentry.
     */
    public var sendDefaultPii: Bool = false
    
    /**
     * When enabled, the SDK tracks performance for UIViewController subclasses and HTTP requests
     * automatically. It also measures the app start and slow and frozen frames.
     * @note The default is @c YES .
     * @note Performance Monitoring must be enabled for this flag to take effect. See:
     * https://docs.sentry.io/platforms/apple/performance/
     */
    public var enableAutoPerformanceTracing: Bool = true
    
    /**
     * We're working to update our Performance product offering in order to be able to provide better
     * insights and highlight specific actions you can take to improve your mobile app's overall
     * performance. The performanceV2 option changes the following behavior: The app start duration will
     * now finish when the first frame is drawn instead of when the OS posts the
     * UIWindowDidBecomeVisibleNotification. This change will be the default in the next major version.
     */
    public var enablePerformanceV2: Bool = false
    
    /**
     * @warning This is an experimental feature and may still have bugs.
     *
     * When enabled, the SDK finishes the ongoing transaction bound to the scope and links them to the
     * crash event when your app crashes. The SDK skips adding profiles to increase the chance of
     * keeping the transaction.
     *
     * @note The default is @c NO .
     */
    public var enablePersistingTracesWhenCrashing: Bool = false
    
    /**
     * A block that configures the initial scope when starting the SDK.
     * @discussion The block receives a suggested default scope. You can either
     * configure and return this, or create your own scope instead.
     * @note The default simply returns the passed in scope.
     */
    public var initialScope: (Scope) -> Scope = { scope in scope }
    
#if os(iOS) || os(tvOS) || os(visionOS)
    /**
     * When enabled, the SDK tracks performance for UIViewController subclasses.
     * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
     * configurations even when targeting iOS or tvOS platforms.
     * @note The default is @c YES .
     */
    public var enableUIViewControllerTracing: Bool = true
    
    /**
     * Automatically attaches a screenshot when capturing an error or exception.
     * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
     * configurations even when targeting iOS or tvOS platforms.
     * @note Default value is @c NO .
     */
    public var attachScreenshot: Bool = false
    
    /**
     * @warning This is an experimental feature and may still have bugs.
     * @brief Automatically attaches a textual representation of the view hierarchy when capturing an
     * error event.
     * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
     * configurations even when targeting iOS or tvOS platforms.
     * @note Default value is @c NO .
     */
    public var attachViewHierarchy: Bool = false
    
    /**
     * @brief If enabled, view hierarchy attachment will contain view `accessibilityIdentifier`.
     * Set it to @c NO if your project uses `accessibilityIdentifier` for PII.
     * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
     * configurations even when targeting iOS or tvOS platforms.
     * @note Default value is @c YES.
     */
    public var reportAccessibilityIdentifier: Bool = true
    
    /**
     * When enabled, the SDK creates transactions for UI events like buttons clicks, switch toggles,
     * and other ui elements that uses UIControl @c sendAction:to:forEvent:
     * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
     * configurations even when targeting iOS or tvOS platforms.
     * @note Default value is @c YES .
     */
    public var enableUserInteractionTracing: Bool = true
    
    /**
     * How long an idle transaction waits for new children after all its child spans finished. Only UI
     * event transactions are idle transactions.
     * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
     * configurations even when targeting iOS or tvOS platforms.
     * @note The default is 3 seconds.
     */
    public var idleTimeout: TimeInterval = 3.0
    
    /**
     * Report pre-warmed app starts by dropping the first app start spans if pre-warming paused
     * during these steps. This approach will shorten the app start duration, but it represents the
     * duration a user has to wait after clicking the app icon until the app is responsive.
     *
     * @note You can filter for different app start types in Discover with
     * @c app_start_type:cold.prewarmed ,
     * @c app_start_type:warm.prewarmed , @c app_start_type:cold , and @c app_start_type:warm .
     * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
     * configurations even when targeting iOS or tvOS platforms.
     * @note Default value is @c NO .
     */
    public var enablePreWarmedAppStartTracing: Bool = false
#endif
    
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
    /**
     * Settings to configure the session replay.
     */
    public var sessionReplay: SentryReplayOptions = SentryReplayOptions()
#endif
    
    /**
     * When enabled, the SDK tracks performance for HTTP requests if auto performance tracking and
     * @c enableSwizzling are enabled.
     * @note The default is @c YES .
     * @discussion If you want to enable or disable network breadcrumbs, please use
     * @c enableNetworkBreadcrumbs instead.
     */
    public var enableNetworkTracking: Bool = true
    
    /**
     * When enabled, the SDK tracks performance for file IO reads and writes with NSData if auto
     * performance tracking and enableSwizzling are enabled.
     * @note The default is @c YES .
     */
    public var enableFileIOTracing: Bool = true
    
#if !SDK_V9
    /**
     * Indicates whether tracing should be enabled.
     * @discussion Enabling this sets @c tracesSampleRate to @c 1 if both @c tracesSampleRate and
     * @c tracesSampler are @c nil. Changing either @c tracesSampleRate or @c tracesSampler to a value
     * other then @c nil will enable this in case this was never changed before.
     */
    @available(*, deprecated, message: "Use tracesSampleRate or tracesSampler instead")
    public var enableTracing: Bool {
        get {
            return _enableTracing
        }
        set {
            _enableTracing = newValue
            if newValue && tracesSampleRate == nil && tracesSampler == nil {
                tracesSampleRate = NSNumber(value: 1.0)
            }
            _enableTracingManual = true
        }
    }
#endif // !SDK_V9
    
    /**
     * Indicates the percentage of the tracing data that is collected.
     * @discussion Specifying @c 0 or @c nil discards all trace data, @c 1.0 collects all trace data,
     * @c 0.01 collects 1% of all trace data.
     * @note The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default.
     * @note The default is @c 0 .
     */
    public var tracesSampleRate: NSNumber? {
        didSet {
            if let tracesSampleRate = tracesSampleRate {
                if !sentry_isValidSampleRate(tracesSampleRate) {
                    self.tracesSampleRate = SENTRY_DEFAULT_TRACES_SAMPLE_RATE
                } else {
#if !SDK_V9
                    if !_enableTracingManual {
                        _enableTracing = true
                    }
#endif // !SDK_V9
                }
            }
        }
    }
    
    /**
     * A callback to a user defined traces sampler function.
     * @discussion Specifying @c 0 or @c nil discards all trace data, @c 1.0 collects all trace data,
     * @c 0.01 collects 1% of all trace data.
     * @note The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default of @c 0 .
     * @note If @c enableAppLaunchProfiling is @c YES , this function will be called during SDK start
     * with @c SentrySamplingContext.forNextAppLaunch set to @c YES, and the result will be persisted to
     * disk for use on the next app launch.
     */
    public var tracesSampler: SentryTracesSamplerCallback? {
        didSet {
#if !SDK_V9
            if tracesSampler != nil && !_enableTracingManual {
                _enableTracing = true
            }
#endif // !SDK_V9
        }
    }
    
    /**
     * If tracing is enabled or not.
     * @discussion @c YES if @c tracesSampleRateis > @c 0 and \<= @c 1
     * or a @c tracesSampler is set, otherwise @c NO.
     */
    public var isTracingEnabled: Bool {
#if !SDK_V9
        guard _enableTracing else { return false }
#endif // !SDK_V9
        
        if tracesSampler != nil {
            return true
        }
        if let tracesSampleRate {
            return tracesSampleRate.doubleValue > 0
        }
        return false
    }
    
    /**
     * A list of string prefixes of framework names that belong to the app.
     * @note This option takes precedence over @c inAppExcludes.
     * @note By default, this contains @c CFBundleExecutable to mark it as "in-app".
     */
    public private(set) var inAppIncludes: [String] = []
    
    /**
     * Adds an item to the list of @c inAppIncludes.
     * @param inAppInclude The prefix of the framework name.
     */
    public func addInAppInclude(_ inAppInclude: String) {
        inAppIncludes.append(inAppInclude)
    }
    
    /**
     * A list of string prefixes of framework names that do not belong to the app, but rather to
     * third-party frameworks.
     * @note By default, frameworks considered not part of the app will be hidden from stack
     * traces.
     * @note This option can be overridden using @c inAppIncludes.
     */
    public private(set) var inAppExcludes: [String] = []
    
    /**
     * Adds an item to the list of @c inAppExcludes.
     * @param inAppExclude The prefix of the frameworks name.
     */
    public func addInAppExclude(_ inAppExclude: String) {
        inAppExcludes.append(inAppExclude)
    }
    
    /**
     * Set as delegate on the @c NSURLSession used for all network data-transfer tasks performed by
     * Sentry.
     *
     * @discussion The SDK ignores this option when using @c urlSession.
     */
    public weak var urlSessionDelegate: URLSessionDelegate?
    
    /**
     * Use this property, so the transport uses this  @c NSURLSession with your configuration for
     * sending requests to Sentry.
     *
     * If not set, the SDK will create a new @c NSURLSession with @c [NSURLSessionConfiguration
     * ephemeralSessionConfiguration].
     *
     * @note Default is @c nil.
     */
    public var urlSession: URLSession?
    
    /**
     * Wether the SDK should use swizzling or not.
     * @discussion When turned off the following features are disabled: breadcrumbs for touch events and
     * navigation with @c UIViewControllers, automatic instrumentation for @c UIViewControllers,
     * automatic instrumentation for HTTP requests, automatic instrumentation for file IO with
     * @c NSData, and automatically added sentry-trace header to HTTP requests for distributed tracing.
     * @note Default is @c YES.
     */
    public var enableSwizzling: Bool = true
    
    /**
     * A set of class names to ignore for swizzling.
     *
     * @discussion The SDK checks if a class name of a class to swizzle contains a class name of this
     * array. For example, if you add MyUIViewController to this list, the SDK excludes the following
     * classes from swizzling: YourApp.MyUIViewController, YourApp.MyUIViewControllerA,
     * MyApp.MyUIViewController.
     * We can't use an @c NSSet<Class>  here because we use this as a workaround for which users have
     * to pass in class names that aren't available on specific iOS versions. By using @c
     * NSSet<NSString *>, users can specify unavailable class names.
     *
     * @note Default is an empty set.
     */
    public var swizzleClassNameExcludes: Set<String> = []
    
    /**
     * When enabled, the SDK tracks the performance of Core Data operations. It requires enabling
     * performance monitoring. The default is @c YES.
     * @see <https://docs.sentry.io/platforms/apple/performance/>
     */
    public var enableCoreDataTracing: Bool = true
    
#if !(os(watchOS) || os(tvOS) || os(visionOS))
    /**
     * Block used to configure the continuous profiling options.
     * @warning Continuous profiling is an experimental feature and may contain bugs.
     * @seealso @c SentryProfileOptions, @c SentrySDK.startProfiler and @c SentrySDK.stopProfiler .
     */
    public var configureProfiling: ((SentryProfileOptions) -> Void)?
    
#if !SDK_V9
    /**
     * @warning This is an experimental feature and may still have bugs.
     * Set to @c YES to run the profiler as early as possible in an app launch, before you would
     * normally have the opportunity to call @c SentrySDK.start . If @c profilesSampleRate is nonnull,
     * the @c tracesSampleRate and @c profilesSampleRate are persisted to disk and read on the next app
     * launch to decide whether to profile that launch.
     * @warning If @c profilesSampleRate is @c nil then a continuous profile will be started on every
     * launch; if you desire sampling profiled launches, you must compute your own sample rate to decide
     * whether to set this property to @c YES or @c NO .
     * @warning This property is deprecated and will be removed in a future version of the SDK. See
     * @c SentryProfileOptions.startOnAppStart and @c SentryProfileOptions.lifecycle .
     * @note Profiling is automatically disabled if a thread sanitizer is attached.
     */
    @available(*, deprecated, message: "This property is deprecated and will be removed in a future version of the SDK. See SentryProfileOptions.startOnAppStart and SentryProfileOptions.lifecycle")
    var enableAppLaunchProfiling: Bool = false
    
    /**
     * Indicates the percentage of the profiling data that is collected.
     * @discussion Specifying @c 0 or @c nil discards all profiling data, @c 1.0 collects all profiling data,
     * @c 0.01 collects 1% of all profiling data.
     * @note The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default.
     * @note The default is @c 0 .
     */
    //    @available(*, deprecated, message: "This property is deprecated and will be removed in a future version of the SDK. See SentryProfileOptions.sessionSampleRate")
    public var profilesSampleRate: NSNumber? {
        didSet {
            if let rate = profilesSampleRate {
                if sentry_isValidSampleRate(rate) {
                    profilesSampleRate = rate
                } else {
                    profilesSampleRate = SENTRY_DEFAULT_PROFILES_SAMPLE_RATE
                }
            }
        }
    }
    
    /**
     * A callback to a user defined profiles sampler function.
     * @discussion Specifying @c 0 or @c nil discards all profiling data, @c 1.0 collects all profiling data,
     * @c 0.01 collects 1% of all profiling data.
     * @note The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default of @c 0 .
     */
    @available(*, deprecated, message: "This property is deprecated and will be removed in a future version of the SDK. See SentryProfileOptions.sessionSampleRate")
    public var profilesSampler: SentryTracesSamplerCallback?
    
    @available(*, deprecated, message: "This property is deprecated and will be removed in a future version of the SDK.")
    var isProfilingEnabled: Bool {
        let isRateEnabled = profilesSampleRate.map { $0.doubleValue > 0 } ?? false
        return isRateEnabled || profilesSampler != nil || enableProfiling
    }
    
    /**
     * @brief Whether to enable the sampling profiler.
     * @note Profiling is not supported on watchOS or tvOS.
     * @deprecated Use @c profilesSampleRate instead. Setting @c enableProfiling to @c YES is the
     * equivalent of setting @c profilesSampleRate to @c 1.0  If @c profilesSampleRate is set, it will
     * take precedence over this setting.
     * @note Default is @c NO.
     * @note Profiling is automatically disabled if a thread sanitizer is attached.
     */
    @available(*, deprecated, message: "Use profilesSampleRate or profilesSampler instead. This property will be removed in a future version of the SDK")
    public var enableProfiling: Bool = false
#endif // !SDK_V9
#endif // !(os(watchOS) || os(tvOS) || os(visionOS))
    
    /**
     * Whether to send client reports, which contain statistics about discarded events.
     * @note The default is @c YES.
     * @see <https://develop.sentry.dev/sdk/client-reports/>
     */
    public var sendClientReports: Bool = true
    
    /**
     * When enabled, the SDK tracks when the application stops responding for a specific amount of
     * time defined by the @c appHangsTimeoutInterval option.
     * @note The default is @c YES
     * @note ANR tracking is automatically disabled if a debugger is attached.
     */
    public var enableAppHangTracking: Bool = true
    
#if os(iOS) || os(tvOS) || os(visionOS)
    
#if !SDK_V9
    public var enableAppHangTrackingV2: Bool = false
#endif // !SDK_V9
    
    /**
     * When enabled the SDK reports non-fully-blocking app hangs. A non-fully-blocking app hang is when
     * the app appears stuck to the user but can still render a few frames. For more information see @c
     * enableAppHangTrackingV2.
     *
     * @note The default is @c YES. This feature only works when @c enableAppHangTrackingV2 is enabled.
     */
    public var enableReportNonFullyBlockingAppHangs: Bool = true
#endif
    
    /**
     * The minimum amount of time an app should be unresponsive to be classified as an App Hanging.
     * @note The actual amount may be a little longer.
     * @note Avoid using values lower than 100ms, which may cause a lot of app hangs events being
     * transmitted.
     * @note The default value is 2 seconds.
     */
    public var appHangTimeoutInterval: TimeInterval = 2.0
    
    /**
     * When enabled, the SDK adds breadcrumbs for various system events.
     * @note Default value is @c YES.
     */
    public var enableAutoBreadcrumbTracking: Bool = true
    
    /**
     * An array of hosts or regexes that determines if outgoing HTTP requests will get
     * extra @c trace_id and @c baggage headers added.
     * @discussion This array can contain instances of @c NSString which should match the URL (using
     * @c contains ), and instances of @c NSRegularExpression, which will be used to check the whole
     * URL.
     * @note The default value adds the header to all outgoing requests.
     * @see https://docs.sentry.io/platforms/apple/configuration/options/#trace-propagation-targets
     */
    public var tracePropagationTargets: [AnyObject] = [] {
        didSet {
            for targetCheck in tracePropagationTargets {
                if !targetCheck.isKind(of: NSRegularExpression.self) && !targetCheck.isKind(of: NSString.self) {
                    SentrySDKLog.warning("Only instances of NSString and NSRegularExpression are supported inside tracePropagationTargets.")
                }
            }
        }
    }
    
    /**
     * When enabled, the SDK captures HTTP Client errors.
     * @note This feature requires @c enableSwizzling enabled as well.
     * @note Default value is @c YES.
     */
    public var enableCaptureFailedRequests: Bool = true
    
    /**
     * The SDK will only capture HTTP Client errors if the HTTP Response status code is within the
     * defined range.
     * @note Defaults to 500 - 599.
     */
    public var failedRequestStatusCodes: [HttpStatusCodeRange] = []
    
    /**
     * An array of hosts or regexes that determines if HTTP Client errors will be automatically
     * captured.
     * @discussion This array can contain instances of @c NSString which should match the URL (using
     * @c contains ), and instances of @c NSRegularExpression, which will be used to check the whole
     * URL.
     * @note The default value automatically captures HTTP Client errors of all outgoing requests.
     */
    public var failedRequestTargets: [AnyObject] = [] {
        didSet {
            for targetCheck in failedRequestTargets {
                if !targetCheck.isKind(of: NSRegularExpression.self) && !targetCheck.isKind(of: NSString.self) {
                    SentrySDKLog.warning("Only instances of NSString and NSRegularExpression are supported inside failedRequestTargets.")
                }
            }
        }
    }
    
#if os(iOS) || os(macOS)
    /**
     * Use this feature to enable the Sentry MetricKit integration.
     *
     * @brief When enabled, the SDK sends @c MXDiskWriteExceptionDiagnostic, @c MXCPUExceptionDiagnostic
     * and
     * @c MXHangDiagnostic to Sentry. The SDK supports this feature from iOS 15 and later and macOS 12
     * and later because, on these versions, @c MetricKit delivers diagnostic reports immediately, which
     * allows the Sentry SDK to apply the current data from the scope.
     * @note This feature is disabled by default.
     */
    @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)
    public var enableMetricKit: Bool {
        get {
            _enableMetricKit
        }
        set {
            _enableMetricKit = newValue
        }
    }
    var _enableMetricKit: Bool = false
    
    /**
     * When enabled, the SDK adds the raw MXDiagnosticPayloads as an attachment to the converted
     * SentryEvent. You need to enable @c enableMetricKit for this flag to work.
     *
     * @note Default value is @c NO.
     */
    @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)
    public var enableMetricKitRawPayload: Bool {
        get {
            _enableMetricKitRawPayload
        }
        set {
            _enableMetricKitRawPayload = newValue
        }
    }
    var _enableMetricKitRawPayload: Bool = false
#endif
    
    /**
     * @warning This is an experimental feature and may still have bugs.
     * @brief By enabling this, every UIViewController tracing transaction will wait
     * for a call to @c SentrySDK.reportFullyDisplayed().
     * @discussion Use this in conjunction with @c enableUIViewControllerTracing.
     * If @c SentrySDK.reportFullyDisplayed() is not called, the transaction will finish
     * automatically after 30 seconds and the `Time to full display` Span will be
     * finished with @c DeadlineExceeded status.
     * @note Default value is `NO`.
     */
    public var enableTimeToFullDisplayTracing: Bool = false
    
    /**
     * This feature is only available from Xcode 13 and from macOS 12.0, iOS 15.0, tvOS 15.0,
     * watchOS 8.0.
     *
     * @warning This is an experimental feature and may still have bugs.
     * @brief Stitches the call to Swift Async functions in one consecutive stack trace.
     * @note Default value is @c NO .
     */
    public var swiftAsyncStacktraces: Bool = false
    
    /**
     * The path to store SDK data, like events, transactions, profiles, raw crash data, etc. We
     recommend only changing this when the default, e.g., in security environments, can't be accessed.
     *
     * @note The default is `NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask,
     YES)`.
     */
    public var cacheDirectoryPath: String
    
    /**
     * Whether to enable Spotlight for local development. For more information see
     * https://spotlightjs.com/.
     *
     * @note Only set this option to @c YES while developing, not in production!
     */
    public var enableSpotlight: Bool = false
    
    /**
     * The Spotlight URL. Defaults to http://localhost:8969/stream. For more information see
     * https://spotlightjs.com/
     */
    public var spotlightUrl: String = "http://localhost:8969/stream"
    
    /**
     * Experimental options for the SDK.
     */
    public var experimental: SentryExperimentalOptions = SentryExperimentalOptions()
    
    @available(iOS 13.0, *)
    @available(iOSApplicationExtension, unavailable)
    public var configureUserFeedback: SentryUserFeedbackConfigurationBlock? {
        get {
            // swiftlint:disable force_unwrapping
            _configureUserFeedback as! SentryUserFeedbackConfigurationBlock?
            // swiftlint:enable force_unwrapping
        }
        set {
            _configureUserFeedback = newValue
            let config = SentryUserFeedbackConfiguration()
            self.userFeedbackConfiguration = config
            configureUserFeedback?(config)
        }
    }
    var _configureUserFeedback: Any?
    
    // MARK: - Internal
    
    @_spi(Private) public var profiling: SentryProfileOptions?
    
    var enableViewRendererV2: Bool {
        self.sessionReplay.enableViewRendererV2
    }
    
    var enableFastViewRendering: Bool {
        self.sessionReplay.enableFastViewRendering
    }
    
    @available(iOS 13.0, *)
    @_spi(Private) public var userFeedbackConfiguration: SentryUserFeedbackConfiguration? {
        get {
            _userFeedbackConfiguration as! SentryUserFeedbackConfiguration?
        }
        set {
            _userFeedbackConfiguration = newValue
        }
    }
    private var _userFeedbackConfiguration: Any?
    
    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
    @_spi(Private) public var isAppHangTrackingV2Disabled: Bool {
        #if SDK_V9
            let isV2Enabled = self.enableAppHangTracking;
        #else
            let isV2Enabled = self.enableAppHangTrackingV2;
        #endif // SDK_V9
            return !isV2Enabled || self.appHangTimeoutInterval <= 0;
    }
    #endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
        
    public override init() {
        // Set default integrations
        integrations = Self.defaultIntegrations
        
        // Set default sample rate
        sampleRate = SENTRY_DEFAULT_SAMPLE_RATE
        
        // Set default traces sample rate
        tracesSampleRate = nil
        
        // Set default release name from bundle info
        if let infoDict = Bundle.main.infoDictionary {
            releaseName = "\(infoDict["CFBundleIdentifier"] ?? "")@\(infoDict["CFBundleShortVersionString"] ?? "")+\(infoDict["CFBundleVersion"] ?? "")"
        }
        
        // Set default inAppIncludes from bundle executable
        if let infoDict = Bundle.main.infoDictionary,
           let bundleExecutable = infoDict["CFBundleExecutable"] as? String {
            inAppIncludes = [bundleExecutable]
        } else {
            inAppIncludes = []
        }
        
        // Set default trace propagation targets (everything allowed)
        if let everythingAllowedRegex = try? NSRegularExpression(pattern: ".*", options: .caseInsensitive) {
            tracePropagationTargets = [everythingAllowedRegex]
            failedRequestTargets = [everythingAllowedRegex]
        }
        
        // Set default failed request status codes (500-599)
        let defaultHttpStatusCodeRange = HttpStatusCodeRange(min: 500, max: 599)
        failedRequestStatusCodes = [defaultHttpStatusCodeRange]
        
        // Set default cache directory path
        cacheDirectoryPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? ""
        
        #if targetEnvironment(macOS)
        // Set DSN from environment variable on macOS
        if let dsn = ProcessInfo.processInfo.environment["SENTRY_DSN"], !dsn.isEmpty {
            self.dsn = dsn
        }
        #endif
        super.init()
    }

    // MARK: - Private
    
    private var _enableTracing: Bool = false
    #if !SDK_V9
    private var _enableTracingManual: Bool = false
    #endif // !SDK_V9
    
    #if !(os(watchOS) || os(tvOS) || os(visionOS))
    #if !SDK_V9
    
    /**
     * Checks if continuous profiling is enabled.
     * @return YES if continuous profiling is enabled, NO otherwise.
     */
    @available(*, deprecated, message: "This property is deprecated and will be removed in a future version of the SDK.")
    @_spi(Private) public func isContinuousProfilingEnabled() -> Bool {
        // this looks a little weird with the `!self.enableProfiling` but that actually is the
        // deprecated way to say "enable trace-based profiling", which necessarily disables continuous
        // profiling as they are mutually exclusive modes
        return profilesSampleRate == nil && profilesSampler == nil && !enableProfiling
    }
    #endif // !SDK_V9
    
    /**
     * Checks if continuous profiling V2 is enabled.
     * @return YES if continuous profiling V2 is enabled, NO otherwise.
     */
    #if !SDK_V9
    @available(*, deprecated, message: "This property is deprecated and will be removed in a future version of the SDK.")
    #endif // !SDK_V9
    @_spi(Private) public func isContinuousProfilingV2Enabled() -> Bool {
        #if SDK_V9
        return profiling != nil
        #else
        return isContinuousProfilingEnabled() && profiling != nil
        #endif // SDK_V9
    }
    
    /**
     * Checks if profiling is correlated to traces.
     * @return YES if profiling is correlated to traces, NO otherwise.
     */
    #if !SDK_V9
    @available(*, deprecated, message: "This property is deprecated and will be removed in a future version of the SDK.")
    #endif // !SDK_V9
    @_spi(Private) public func isProfilingCorrelatedToTraces() -> Bool {
        #if SDK_V9
        return profiling != nil && profiling!.lifecycle == .trace
        #else
        return !isContinuousProfilingEnabled() || (profiling != nil && profiling!.lifecycle == .trace)
        #endif // SDK_V9
    }
    
    #if !SDK_V9
    /**
     * Sets the enable profiling flag (deprecated, test only).
     * @param enableProfiling_DEPRECATED_TEST_ONLY Whether to enable profiling.
     */
    @available(*, deprecated, message: "This property is deprecated and will be removed in a future version of the SDK.")
    @_spi(Private) public func setEnableProfiling_DEPRECATED_TEST_ONLY(_ enableProfiling_DEPRECATED_TEST_ONLY: Bool) {
        enableProfiling = enableProfiling_DEPRECATED_TEST_ONLY
    }
    
    /**
     * Gets the enable profiling flag (deprecated, test only).
     * @return YES if profiling is enabled, NO otherwise.
     */
    @available(*, deprecated, message: "This property is deprecated and will be removed in a future version of the SDK.")
    @_spi(Private) public func enableProfiling_DEPRECATED_TEST_ONLY() -> Bool {
        return enableProfiling
    }
    #endif // !SDK_V9
    #endif // !(os(watchOS) || os(tvOS) || os(visionOS))
}
