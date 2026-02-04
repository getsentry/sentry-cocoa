// swiftlint:disable file_length
@_implementationOnly import _SentryPrivate
import Foundation

/// The main entry point for the Sentry SDK.
/// We recommend using `start(configureOptions:)` to initialize Sentry.
@objc public final class SentrySDK: NSObject {
    
    // MARK: - Public
    
    /// The current active transaction or span bound to the scope.
    @objc public static var span: Span? {
        return SentrySDKInternal.span
    }
    
    /// Indicates whether the Sentry SDK is enabled.
    @objc public static var isEnabled: Bool {
        return SentrySDKInternal.isEnabled
    }

    #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    /// API to control session replay
    @objc public static var replay: SentryReplayApi {
        return SentrySDKInternal.replay
    }
    #endif

    /// API to access Sentry logs
    @objc public static var logger: SentryLogger {
        if !SentrySDKInternal.isEnabled {
            SentrySDKLog.fatal("Logs called before SentrySDK.start() will not be sent to Sentry.")
        }
        if let logger = SentrySDKInternal.currentHub()._swiftLogger as? SentryLogger {
            return logger
        } else {
            SentrySDKLog.fatal("Unable to access configured logger. Logs will not be sent to Sentry.")
            return SentryLogger(dateProvider: SentryDependencyContainer.sharedInstance().dateProvider)
        }
    }

    /// API to access Sentry Metrics.
    ///
    /// Sentry Metrics allows you to send counters, gauges, and distributions from your applications to Sentry.
    /// Once in Sentry, these metrics can be viewed alongside related errors, traces, and logs, and searched
    /// using their individual attributes.
    ///
    /// The `metrics` namespace exposes three methods to capture different types of metric information:
    /// - ``SentryMetricsApiProtocol/count(key:value:attributes:)``: Track discrete occurrence counts
    ///   (e.g., button clicks, API requests, errors).
    /// - ``SentryMetricsApiProtocol/gauge(key:value:unit:attributes:)``: Track values that can go up and down
    ///   (e.g., memory usage, queue depth, active connections).
    /// - ``SentryMetricsApiProtocol/distribution(key:value:unit:attributes:)``: Track the distribution of a value
    ///   over time for statistical analysis like percentiles (e.g., response times, request durations).
    ///
    /// Gauge and distribution methods support optional units (via ``SentryUnit``) and attributes for filtering and grouping.
    /// Count metrics do not support units.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Simple counter
    /// SentrySDK.metrics.count(key: "button_click", value: 1)
    ///
    /// // Distribution with unit and attributes
    /// SentrySDK.metrics.distribution(
    ///     key: "http.request.duration",
    ///     value: 187.5,
    ///     unit: .millisecond,
    ///     attributes: ["endpoint": "/api/data", "cached": false]
    /// )
    /// ```
    ///
    /// ## Requirements
    ///
    /// Metrics are enabled by default even though it is an experimental feature, because you must still
    /// manually call the API methods (``SentryMetricsApiProtocol/count(key:value:attributes:)``,
    /// ``SentryMetricsApiProtocol/gauge(key:value:unit:attributes:)``, or
    /// ``SentryMetricsApiProtocol/distribution(key:value:unit:attributes:)``) to use it.
    ///
    /// To disable metrics, set ``Options/experimental`` ``SentryExperimentalOptions/enableMetrics`` to `false`.
    ///
    /// - Note: This feature is currently in open beta.
    ///
    /// - Important: The Metrics API has been designed and optimized for Swift. Objective-C support is not
    ///   currently available. If you need Objective-C support, please open an issue at
    ///   https://github.com/getsentry/sentry-cocoa/issues to show demand for this feature.
    ///
    /// - SeeAlso: For complete documentation, visit https://docs.sentry.io/platforms/apple/metrics/
    public static var metrics: SentryMetricsApiProtocol = SentryMetricsApi(dependencies: SentryDependencyContainer.sharedInstance())

    /// Inits and configures Sentry (`SentryHub`, `SentryClient`) and sets up all integrations. Make sure to
    /// set a valid DSN.
    /// - note: Call this method on the main thread. When calling it from a background thread, the
    /// SDK starts on the main thread async.
    @objc public static func start(options: Options) {
        // We save the options before checking for Xcode preview because
        // we will use this options in the preview
        setStart(with: options)
        guard SentryDependencyContainer.sharedInstance().processInfoWrapper
                    .environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            // Using NSLog because SentryLog was not initialized yet.
            NSLog("[SENTRY] [WARNING] SentrySDK not started. Running from Xcode preview.")
            return
        }
        SentrySDKInternal.start(options: options)
    }
    
    /// Inits and configures Sentry (`SentryHub`, `SentryClient`) and sets up all integrations. Make sure to
    /// set a valid DSN.
    /// - note: Call this method on the main thread. When calling it from a background thread, the
    /// SDK starts on the main thread async.
    @objc public static func start(configureOptions: @escaping (Options) -> Void) {
        let options = Options()
        configureOptions(options)
        start(options: options)
    }
    
    // MARK: - Event Capture
    
    /// Captures a manually created event and sends it to Sentry.
    /// - parameter event: The event to send to Sentry.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureEvent:)
    @discardableResult public static func capture(event: Event) -> SentryId {
        return SentrySDKInternal.capture(event: event)
    }
    
    /// Captures a manually created event and sends it to Sentry. Only the data in this scope object will
    /// be added to the event. The global scope will be ignored.
    /// - parameter event: The event to send to Sentry.
    /// - parameter scope: The scope containing event metadata.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureEvent:withScope:)
    @discardableResult public static func capture(event: Event, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(event: event, scope: scope)
    }
    
    /// Captures a manually created event and sends it to Sentry. Maintains the global scope but mutates
    /// scope data for only this call.
    /// - parameter event: The event to send to Sentry.
    /// - parameter block: The block mutating the scope only for this call.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureEvent:withScopeBlock:)
    @discardableResult public static func capture(event: Event, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(event: event, block: block)
    }
    
    // MARK: - Transaction Management
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter name: The transaction name.
    /// - parameter operation: Short code identifying the type of operation the span is measuring.
    /// - returns: The created transaction.
    @objc @discardableResult public static func startTransaction(name: String, operation: String) -> Span {
        return SentrySDKInternal.startTransaction(name: name, operation: operation)
    }
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter name: The transaction name.
    /// - parameter operation: Short code identifying the type of operation the span is measuring.
    /// - parameter bindToScope: Indicates whether the SDK should bind the new transaction to the scope.
    /// - returns: The created transaction.
    @objc @discardableResult public static func startTransaction(name: String, operation: String, bindToScope: Bool) -> Span {
        return SentrySDKInternal.startTransaction(name: name, operation: operation, bindToScope: bindToScope)
    }
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter transactionContext: The transaction context.
    /// - returns: The created transaction.
    @objc(startTransactionWithContext:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext)
    }
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter transactionContext: The transaction context.
    /// - parameter bindToScope: Indicates whether the SDK should bind the new transaction to the scope.
    /// - returns: The created transaction.
    @objc(startTransactionWithContext:bindToScope:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext, bindToScope: Bool) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext, bindToScope: bindToScope)
    }
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter transactionContext: The transaction context.
    /// - parameter bindToScope: Indicates whether the SDK should bind the new transaction to the scope.
    /// - parameter customSamplingContext: Additional information about the sampling context.
    /// - returns: The created transaction.
    @objc(startTransactionWithContext:bindToScope:customSamplingContext:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext, bindToScope: Bool, customSamplingContext: [String: Any]) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext, bindToScope: bindToScope, customSamplingContext: customSamplingContext)
    }
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter transactionContext: The transaction context.
    /// - parameter customSamplingContext: Additional information about the sampling context.
    /// - returns: The created transaction.
    @objc(startTransactionWithContext:customSamplingContext:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext, customSamplingContext: [String: Any]) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext, customSamplingContext: customSamplingContext)
    }
    
    // MARK: - Error Capture
    
    /// Captures an error event and sends it to Sentry.
    /// - parameter error: The error to send to Sentry.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureError:)
    @discardableResult public static func capture(error: Error) -> SentryId {
        return SentrySDKInternal.capture(error: error)
    }
    
    /// Captures an error event and sends it to Sentry. Only the data in this scope object will be added
    /// to the event. The global scope will be ignored.
    /// - parameter error: The error to send to Sentry.
    /// - parameter scope: The scope containing event metadata.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureError:withScope:)
    @discardableResult public static func capture(error: Error, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(error: error, scope: scope)
    }
    
    /// Captures an error event and sends it to Sentry. Maintains the global scope but mutates scope data
    /// for only this call.
    /// - parameter error: The error to send to Sentry.
    /// - parameter block: The block mutating the scope only for this call.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureError:withScopeBlock:)
    @discardableResult public static func capture(error: Error, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(error: error, block: block)
    }
    
    // MARK: - Exception Capture
    
    /// Captures an exception event and sends it to Sentry.
    /// - parameter exception: The exception to send to Sentry.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureException:)
    @discardableResult public static func capture(exception: NSException) -> SentryId {
        return SentrySDKInternal.capture(exception: exception)
    }
    
    /// Captures an exception event and sends it to Sentry. Only the data in this scope object will be
    /// added to the event. The global scope will be ignored.
    /// - parameter exception: The exception to send to Sentry.
    /// - parameter scope: The scope containing event metadata.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureException:withScope:)
    @discardableResult public static func capture(exception: NSException, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(exception: exception, scope: scope)
    }
    
    /// Captures an exception event and sends it to Sentry. Maintains the global scope but mutates scope
    /// data for only this call.
    /// - parameter exception: The exception to send to Sentry.
    /// - parameter block: The block mutating the scope only for this call.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureException:withScopeBlock:)
    @discardableResult public static func capture(exception: NSException, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(exception: exception, block: block)
    }
    
    // MARK: - Message Capture
    
    /// Captures a message event and sends it to Sentry.
    /// - parameter message: The message to send to Sentry.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureMessage:)
    @discardableResult public static func capture(message: String) -> SentryId {
        return SentrySDKInternal.capture(message: message)
    }
    
    /// Captures a message event and sends it to Sentry. Only the data in this scope object will be added
    /// to the event. The global scope will be ignored.
    /// - parameter message: The message to send to Sentry.
    /// - parameter scope: The scope containing event metadata.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureMessage:withScope:)
    @discardableResult public static func capture(message: String, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(message: message, scope: scope)
    }
    
    /// Captures a message event and sends it to Sentry. Maintains the global scope but mutates scope
    /// data for only this call.
    /// - parameter message: The message to send to Sentry.
    /// - parameter block: The block mutating the scope only for this call.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureMessage:withScopeBlock:)
    @discardableResult public static func capture(message: String, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(message: message, block: block)
    }
    
    /// Captures user feedback that was manually gathered and sends it to Sentry.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - parameter feedback: The feedback to send to Sentry.
    /// - note: If you'd prefer not to have to build the UI required to gather the feedback from the user,
    /// see `SentryOptions.configureUserFeedback` to customize a fully managed integration. See
    /// https://docs.sentry.io/platforms/apple/user-feedback/ for more information.
    @objc(captureFeedback:)
    public static func capture(feedback: SentryFeedback) {
      SentrySDKInternal.captureSerializedFeedback(
        feedback.serialize(),
        withEventId: feedback.eventId.sentryIdString,
        attachments: feedback.attachmentsForEnvelope())
    }
    
    #if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    /// The API for capturing user feedback.
    ///
    /// Use this to programmatically show the feedback form or access feedback-related functionality.
    @objc public static let feedback = {
      return SentryFeedbackAPI()
    }()
    #endif
    
    /// Adds a `Breadcrumb` to the current `Scope` of the current `Hub`. If the total number of breadcrumbs
    /// exceeds the `SentryOptions.maxBreadcrumbs` the SDK removes the oldest breadcrumb.
    /// - parameter crumb: The `Breadcrumb` to add to the current `Scope` of the current `Hub`.
    @objc(addBreadcrumb:)
    public static func addBreadcrumb(_ crumb: Breadcrumb) {
        SentrySDKInternal.addBreadcrumb(crumb)
    }
    
    /// Use this method to modify the current `Scope` of the current `Hub`. The SDK uses the `Scope` to attach
    /// contextual data to events.
    /// - parameter callback: The callback for configuring the current `Scope` of the current `Hub`.
    @objc(configureScope:)
    public static func configureScope(_ callback: @escaping (Scope) -> Void) {
        SentrySDKInternal.configureScope(callback)
    }
    
    // MARK: - Crash Detection
    
    /// Checks if the last program execution terminated with a crash.
    @objc public static var crashedLastRun: Bool {
        return SentrySDKInternal.crashedLastRun
    }
    
    /// Checks if the SDK detected a start-up crash during SDK initialization.
    /// - note: The SDK init waits synchronously for up to 5 seconds to flush out events if the app crashes
    /// within 2 seconds after the SDK init.
    /// - returns: true if the SDK detected a start-up crash and false if not.
    @objc public static var detectedStartUpCrash: Bool {
        return SentrySDKInternal.detectedStartUpCrash
    }
    
    // MARK: - User Management
    
    /// Set `user` to the current `Scope` of the current `Hub`.
    /// - parameter user: The user to set to the current `Scope`.
    /// - note: You must start the SDK before calling this method, otherwise it doesn't set the user.
    @objc public static func setUser(_ user: User?) {
        SentrySDKInternal.setUser(user)
    }
    
    // MARK: - Session Management
    
    /// Starts a new `SentrySession`. If there's a running `SentrySession`, it ends it before starting the
    /// new one. You can use this method in combination with `endSession` to manually track
    /// sessions. The SDK uses `SentrySession` to inform Sentry about release and project
    /// associated project health.
    @objc public static func startSession() {
        SentrySDKInternal.startSession()
    }
    
    /// Ends the current `SentrySession`. You can use this method in combination with `startSession` to
    /// manually track `SentrySessions`. The SDK uses `SentrySession` to inform Sentry about release and
    /// project associated project health.
    @objc public static func endSession() {
        SentrySDKInternal.endSession()
    }
    
    /// This forces a crash, useful to test the `SentryCrash` integration.
    ///
    /// - note: The SDK can't report a crash when a debugger is attached. Your application needs to run
    /// without a debugger attached to capture the crash and send it to Sentry the next time you launch
    /// your application.
    @objc public static func crash() {
        SentrySDKInternal.crash()
    }
    
    /// Reports to the ongoing `UIViewController` transaction
    /// that the screen contents are fully loaded and displayed,
    /// which will create a new span.
    ///
    /// - seealso:
    /// https://docs.sentry.io/platforms/cocoa/performance/instrumentation/automatic-instrumentation/#time-to-full-display
    @objc public static func reportFullyDisplayed() {
        SentrySDKInternal.reportFullyDisplayed()
    }
    
    // MARK: - App Hang Tracking
    
    /// Pauses sending detected app hangs to Sentry.
    ///
    /// This method doesn't close the detection of app hangs. Instead, the app hang detection
    /// will ignore detected app hangs until you call `resumeAppHangTracking`.
    @objc public static func pauseAppHangTracking() {
        SentrySDKInternal.pauseAppHangTracking()
    }
    
    /// Resumes sending detected app hangs to Sentry.
    @objc public static func resumeAppHangTracking() {
        SentrySDKInternal.resumeAppHangTracking()
    }

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    // MARK: - App Launch Tracking

    /// Returns a task object that can be used to extend the app launch duration measurement.
    ///
    /// When ``Options/enableStandaloneAppStartTransaction`` is enabled, the SDK captures app startup
    /// time as a standalone transaction. By default, the app launch ends when the first frame is rendered.
    ///
    /// Call this method to get a task object, then call ``SentryAppLaunchTask/finish()`` on it when
    /// your app has completed its initialization and is ready for user interaction. This extends the
    /// app startup measurement to include additional initialization work.
    ///
    /// - Returns: A task object to mark app launch completion, or `nil` if:
    ///   - ``Options/enableStandaloneAppStartTransaction`` is not enabled
    ///   - The app start transaction has already been created
    ///   - An extended launch task has already been created
    ///
    /// - Note: This method must be called before the first frame is rendered for the task to have any effect.
    ///
    /// - Important: This method must be called from the main thread.
    ///
    /// ## Example
    /// ```swift
    /// // In your AppDelegate or early initialization code:
    /// let launchTask = SentrySDK.extendedAppLaunchTask()
    ///
    /// // After your initialization is complete:
    /// launchTask?.finish()
    /// ```
    @objc public static func extendedAppLaunchTask() -> SentryAppLaunchTask? {
        // Must be called on main thread
        return SentryStandaloneAppStartTrackingIntegration.createExtendedAppLaunchTask()
    }
    #endif

    /// Waits synchronously for the SDK to flush out all queued and cached items for up to the specified
    /// timeout in seconds. If there is no internet connection, the function returns immediately. The SDK
    /// doesn't dispose the client or the hub.
    /// - parameter timeout: The time to wait for the SDK to complete the flush.
    /// - note: This might take slightly longer than the specified timeout if there are many batched logs to capture.
    @objc(flush:)
    public static func flush(timeout: TimeInterval) {
        SentrySDKInternal.flush(timeout: timeout)
    }
    
    /// Closes the SDK, uninstalls all the integrations, and calls `flush` with
    /// `SentryOptions.shutdownTimeInterval`.
    @objc public static func close() {
        SentrySDKInternal.close()
    }
    
#if !(os(watchOS) || os(tvOS) || os(visionOS))
    /// Start a new continuous profiling session if one is not already running.
    /// - warning: Continuous profiling mode is experimental and may still contain bugs.
    /// - note: Unlike transaction-based profiling, continuous profiling does not take into account
    /// `SentryOptions.profilesSampleRate` or `SentryOptions.profilesSampler`. If either of those
    /// options are set, this method does nothing.
    /// - note: Taking into account the above note, if `SentryOptions.configureProfiling` is not set,
    /// calls to this method will always start a profile if one is not already running.
    /// - note: If neither `SentryOptions.profilesSampleRate` nor `SentryOptions.profilesSampler` are
    /// set, and `SentryOptions.configureProfiling` is set, this method does nothing if the profiling
    /// session is not sampled with respect to `SentryOptions.profileSessionSampleRate`, or if it is
    /// sampled but the profiler is already running.
    /// - note: If neither `SentryOptions.profilesSampleRate` nor `SentryOptions.profilesSampler` are
    /// set, and `SentryOptions.configureProfiling` is set, this method does nothing if
    /// `SentryOptions.profileLifecycle` is set to `trace`. In this scenario, the profiler is
    /// automatically started and stopped depending on whether there is an active sampled span, so it is
    /// not permitted to manually start profiling.
    /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
    /// - seealso: https://docs.sentry.io/platforms/apple/guides/ios/profiling/#continuous-profiling
    @objc public static func startProfiler() {
        SentrySDKInternal.startProfiler()
    }
    
    /// Stop a continuous profiling session if there is one ongoing.
    /// - warning: Continuous profiling mode is experimental and may still contain bugs.
    /// - note: Does nothing if `SentryOptions.profileLifecycle` is set to `trace`.
    /// - note: Does not immediately stop the profiler. Profiling data is uploaded at regular timed
    /// intervals; when the current interval completes, then the profiler stops and the data gathered
    /// during that last interval is uploaded.
    /// - note: If a new call to `startProfiler` that would start the profiler is made before the last
    /// interval completes, the profiler will continue running until another call to stop is made.
    /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
    /// - seealso: https://docs.sentry.io/platforms/apple/guides/ios/profiling/#continuous-profiling
    @objc public static func stopProfiler() {
        SentrySDKInternal.stopProfiler()
    }
    #endif

    // MARK: Internal

    /// The option used to start the SDK
    private static var _startOption: Options?
    private static let startOptionLock = NSRecursiveLock()
    // swiftlint:disable:next missing_docs
    @_spi(Private) @objc public static var startOption: Options? {
        startOptionLock.synchronized {
            return _startOption
        }
    }
    // swiftlint:disable:next missing_docs
    @_spi(Private) @objc public static func setStart(with option: Options?) {
        startOptionLock.synchronized {
            _startOption = option
        }
    }
}

// swiftlint:enable file_length
