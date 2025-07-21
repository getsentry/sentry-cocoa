// swiftlint:disable file_length
@_implementationOnly import _SentryPrivate
import Foundation

final class DateProviderBridge: SentryCurrentDateProvider {

    private let dateProvider: SentryInternalCurrentDateProvider

    func date() -> Date {
        self.dateProvider.date()
    }
    
    func timezoneOffset() -> Int {
        self.dateProvider.timezoneOffset()
    }
    
    func systemTime() -> UInt64 {
        self.dateProvider.systemTime()
    }
    
    func systemUptime() -> TimeInterval {
        self.dateProvider.systemUptime()
    }
    
    init(dateProvider: SentryInternalCurrentDateProvider) {
        self.dateProvider = dateProvider
    }
}

/**
 * The main entry point for the SentrySDK.
 * We recommend using `start(configureOptions:)` to initialize Sentry.
 */
@objc open class SentrySDK: NSObject {
    
    // MARK: - Public
    
    /**
     * The current active transaction or span bound to the scope.
     */
    @objc public static var span: Span? {
        return SentrySDKInternal.span
    }
    
    /**
     * Indicates whether the SentrySDK is enabled.
     */
    @objc public static var isEnabled: Bool {
        return SentrySDKInternal.isEnabled
    }

    #if canImport(UIKit) && !SENTRY_NO_UIKIT && (os(iOS) || os(tvOS))
    /**
     * API to control session replay
     */
    @objc public static var replay: SentryReplayApi {
        return SentrySDKInternal.replay
    }
    #endif

    /**
     * API to access Sentry logs
     */
    @objc public static var logger: SentryLogger {
        return _loggerLock.synchronized {
            if let _logger {
                return _logger
            }
            let hub = SentrySwiftHelpers.currentHub()
            var batcher: SentryLogBatcher?
            if let client = hub.getClient(), client.options.experimental.enableLogs {
                batcher = SentryLogBatcher(client: client, dispatchQueue: DependencyScope.dispatchQueueWrapper)
            }
            let logger = SentryLogger(hub: hub, dateProvider: DateProviderBridge(dateProvider: SentrySwiftHelpers.currentDateProvider()), batcher: batcher)
            _logger = logger
            return logger
        }
    }
    
    /**
     * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations. Make sure to
     * set a valid DSN.
     *
     * Call this method on the main thread. When calling it from a background thread, the
     * SDK starts on the main thread async.
     */
    @objc public static func start(options: Options) {
        SentrySDKInternal.start(options: options)
    }
    
    /**
     * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations. Make sure to
     * set a valid DSN.
     *
     * Call this method on the main thread. When calling it from a background thread, the
     * SDK starts on the main thread async.
     */
    @objc public static func start(configureOptions: @escaping (Options) -> Void) {
        SentrySDKInternal.start(configureOptions: configureOptions)
    }
    
    // MARK: - Event Capture
    
    /**
     * Captures a manually created event and sends it to Sentry.
     * @param event The event to send to Sentry.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureEvent:)
    @discardableResult public static func capture(event: Event) -> SentryId {
        return SentrySDKInternal.capture(event: event)
    }
    
    /**
     * Captures a manually created event and sends it to Sentry. Only the data in this scope object will
     * be added to the event. The global scope will be ignored.
     * @param event The event to send to Sentry.
     * @param scope The scope containing event metadata.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureEvent:withScope:)
    @discardableResult public static func capture(event: Event, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(event: event, scope: scope)
    }
    
    /**
     * Captures a manually created event and sends it to Sentry. Maintains the global scope but mutates
     * scope data for only this call.
     * @param event The event to send to Sentry.
     * @param block The block mutating the scope only for this call.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureEvent:withScopeBlock:)
    @discardableResult public static func capture(event: Event, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(event: event, block: block)
    }
    
    // MARK: - Transaction Management
    
    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param name The transaction name.
     * @param operation Short code identifying the type of operation the span is measuring.
     * @return The created transaction.
     */
    @objc @discardableResult public static func startTransaction(name: String, operation: String) -> Span {
        return SentrySDKInternal.startTransaction(name: name, operation: operation)
    }
    
    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param name The transaction name.
     * @param operation Short code identifying the type of operation the span is measuring.
     * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
     * @return The created transaction.
     */
    @objc @discardableResult public static func startTransaction(name: String, operation: String, bindToScope: Bool) -> Span {
        return SentrySDKInternal.startTransaction(name: name, operation: operation, bindToScope: bindToScope)
    }
    
    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param transactionContext The transaction context.
     * @return The created transaction.
     */
    @objc(startTransactionWithContext:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext)
    }
    
    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param transactionContext The transaction context.
     * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
     * @return The created transaction.
     */
    @objc(startTransactionWithContext:bindToScope:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext, bindToScope: Bool) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext, bindToScope: bindToScope)
    }
    
    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param transactionContext The transaction context.
     * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
     * @param customSamplingContext Additional information about the sampling context.
     * @return The created transaction.
     */
    @objc(startTransactionWithContext:bindToScope:customSamplingContext:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext, bindToScope: Bool, customSamplingContext: [String: Any]) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext, bindToScope: bindToScope, customSamplingContext: customSamplingContext)
    }
    
    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param transactionContext The transaction context.
     * @param customSamplingContext Additional information about the sampling context.
     * @return The created transaction.
     */
    @objc(startTransactionWithContext:customSamplingContext:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext, customSamplingContext: [String: Any]) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext, customSamplingContext: customSamplingContext)
    }
    
    // MARK: - Error Capture
    
    /**
     * Captures an error event and sends it to Sentry.
     * @param error The error to send to Sentry.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureError:)
    @discardableResult public static func capture(error: Error) -> SentryId {
        return SentrySDKInternal.capture(error: error)
    }
    
    /**
     * Captures an error event and sends it to Sentry. Only the data in this scope object will be added
     * to the event. The global scope will be ignored.
     * @param error The error to send to Sentry.
     * @param scope The scope containing event metadata.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureError:withScope:)
    @discardableResult public static func capture(error: Error, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(error: error, scope: scope)
    }
    
    /**
     * Captures an error event and sends it to Sentry. Maintains the global scope but mutates scope data
     * for only this call.
     * @param error The error to send to Sentry.
     * @param block The block mutating the scope only for this call.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureError:withScopeBlock:)
    @discardableResult public static func capture(error: Error, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(error: error, block: block)
    }
    
    // MARK: - Exception Capture
    
    /**
     * Captures an exception event and sends it to Sentry.
     * @param exception The exception to send to Sentry.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureException:)
    @discardableResult public static func capture(exception: NSException) -> SentryId {
        return SentrySDKInternal.capture(exception: exception)
    }
    
    /**
     * Captures an exception event and sends it to Sentry. Only the data in this scope object will be
     * added to the event. The global scope will be ignored.
     * @param exception The exception to send to Sentry.
     * @param scope The scope containing event metadata.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureException:withScope:)
    @discardableResult public static func capture(exception: NSException, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(exception: exception, scope: scope)
    }
    
    /**
     * Captures an exception event and sends it to Sentry. Maintains the global scope but mutates scope
     * data for only this call.
     * @param exception The exception to send to Sentry.
     * @param block The block mutating the scope only for this call.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureException:withScopeBlock:)
    @discardableResult public static func capture(exception: NSException, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(exception: exception, block: block)
    }
    
    // MARK: - Message Capture
    
    /**
     * Captures a message event and sends it to Sentry.
     * @param message The message to send to Sentry.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureMessage:)
    @discardableResult public static func capture(message: String) -> SentryId {
        return SentrySDKInternal.capture(message: message)
    }
    
    /**
     * Captures a message event and sends it to Sentry. Only the data in this scope object will be added
     * to the event. The global scope will be ignored.
     * @param message The message to send to Sentry.
     * @param scope The scope containing event metadata.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureMessage:withScope:)
    @discardableResult public static func capture(message: String, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(message: message, scope: scope)
    }
    
    /**
     * Captures a message event and sends it to Sentry. Maintains the global scope but mutates scope
     * data for only this call.
     * @param message The message to send to Sentry.
     * @param block The block mutating the scope only for this call.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @objc(captureMessage:withScopeBlock:)
    @discardableResult public static func capture(message: String, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(message: message, block: block)
    }
    
    #if !SDK_V9
    /**
     * Captures user feedback that was manually gathered and sends it to Sentry.
     * @param userFeedback The user feedback to send to Sentry.
     * @deprecated Use SentrySDK.captureFeedback or use or configure our new managed UX with
     * SentryOptions.configureUserFeedback .
     */
    @available(*, deprecated, message: "Use SentrySDK.back or use or configure our new managed UX with SentryOptions.configureUserFeedback.")
    @objc(captureUserFeedback:)
    public static func capture(userFeedback: UserFeedback) {
        SentrySDKInternal.capture(userFeedback: userFeedback)
    }
    #endif
    
    /**
     * Captures user feedback that was manually gathered and sends it to Sentry.
     * @warning This is an experimental feature and may still have bugs.
     * @param feedback The feedback to send to Sentry.
     * @note If you'd prefer not to have to build the UI required to gather the feedback from the user,
     * see SentryOptions.configureUserFeedback to customize a fully managed integration. See
     * https://docs.sentry.io/platforms/apple/user-feedback/ for more information.
     */
    @objc(captureFeedback:)
    public static func capture(feedback: SentryFeedback) {
        SentrySDKInternal.capture(feedback: feedback)
    }
    
    #if os(iOS) && !SENTRY_NO_UIKIT
    @available(iOS 13.0, *)
    @objc public static let feedback = {
      return SentryFeedbackAPI()
    }()
    #endif
    
    /**
     * Adds a Breadcrumb to the current Scope of the current Hub. If the total number of breadcrumbs
     * exceeds the SentryOptions.maxBreadcrumbs the SDK removes the oldest breadcrumb.
     * @param crumb The Breadcrumb to add to the current Scope of the current Hub.
     */
    @objc(addBreadcrumb:)
    public static func addBreadcrumb(_ crumb: Breadcrumb) {
        SentrySDKInternal.addBreadcrumb(crumb)
    }
    
    /**
     * Use this method to modify the current Scope of the current Hub. The SDK uses the Scope to attach
     * contextual data to events.
     * @param callback The callback for configuring the current Scope of the current Hub.
     */
    @objc(configureScope:)
    public static func configureScope(_ callback: @escaping (Scope) -> Void) {
        SentrySDKInternal.configureScope(callback)
    }
    
    // MARK: - Crash Detection
    
    /**
     * Checks if the last program execution terminated with a crash.
     */
    @objc public static var crashedLastRun: Bool {
        return SentrySDKInternal.crashedLastRun
    }
    
    /**
     * Checks if the SDK detected a start-up crash during SDK initialization.
     *
     * The SDK init waits synchronously for up to 5 seconds to flush out events if the app crashes
     * within 2 seconds after the SDK init.
     *
     * @return true if the SDK detected a start-up crash and false if not.
     */
    @objc public static var detectedStartUpCrash: Bool {
        return SentrySDKInternal.detectedStartUpCrash
    }
    
    // MARK: - User Management
    
    /**
     * Set user to the current Scope of the current Hub.
     * @param user The user to set to the current Scope.
     *
     * You must start the SDK before calling this method, otherwise it doesn't set the user.
     */
    @objc public static func setUser(_ user: User?) {
        SentrySDKInternal.setUser(user)
    }
    
    // MARK: - Session Management
    
    /**
     * Starts a new SentrySession. If there's a running SentrySession, it ends it before starting the
     * new one. You can use this method in combination with endSession to manually track
     * SentrySessions. The SDK uses SentrySession to inform Sentry about release and project
     * associated project health.
     */
    @objc public static func startSession() {
        SentrySDKInternal.startSession()
    }
    
    /**
     * Ends the current SentrySession. You can use this method in combination with startSession to
     * manually track SentrySessions. The SDK uses SentrySession to inform Sentry about release and
     * project associated project health.
     */
    @objc public static func endSession() {
        SentrySDKInternal.endSession()
    }
    
    /**
     * This forces a crash, useful to test the SentryCrash integration.
     *
     * The SDK can't report a crash when a debugger is attached. Your application needs to run
     * without a debugger attached to capture the crash and send it to Sentry the next time you launch
     * your application.
     */
    @objc public static func crash() {
        SentrySDKInternal.crash()
    }
    
    /**
     * Reports to the ongoing UIViewController transaction
     * that the screen contents are fully loaded and displayed,
     * which will create a new span.
     *
     * For more information see our documentation:
     * https://docs.sentry.io/platforms/cocoa/performance/instrumentation/automatic-instrumentation/#time-to-full-display
     */
    @objc public static func reportFullyDisplayed() {
        SentrySDKInternal.reportFullyDisplayed()
    }
    
    // MARK: - App Hang Tracking
    
    /**
     * Pauses sending detected app hangs to Sentry.
     *
     * This method doesn't close the detection of app hangs. Instead, the app hang detection
     * will ignore detected app hangs until you call resumeAppHangTracking.
     */
    @objc public static func pauseAppHangTracking() {
        SentrySDKInternal.pauseAppHangTracking()
    }
    
    /**
     * Resumes sending detected app hangs to Sentry.
     */
    @objc public static func resumeAppHangTracking() {
        SentrySDKInternal.resumeAppHangTracking()
    }
    
    /**
     * Waits synchronously for the SDK to flush out all queued and cached items for up to the specified
     * timeout in seconds. If there is no internet connection, the function returns immediately. The SDK
     * doesn't dispose the client or the hub.
     * @param timeout The time to wait for the SDK to complete the flush.
     */
    @objc(flush:)
    public static func flush(timeout: TimeInterval) {
        SentrySDKInternal.flush(timeout: timeout)
    }
    
    /**
     * Closes the SDK, uninstalls all the integrations, and calls flush with
     * SentryOptions.shutdownTimeInterval .
     */
    @objc public static func close() {
        SentrySDKInternal.close()
    }
    
#if !(os(watchOS) || os(tvOS) || (swift(>=5.9) && os(visionOS)))
    /**
     * Start a new continuous profiling session if one is not already running.
     * @warning Continuous profiling mode is experimental and may still contain bugs.
     * @note Unlike transaction-based profiling, continuous profiling does not take into account
     * SentryOptions.profilesSampleRate or SentryOptions.profilesSampler . If either of those
     * options are set, this method does nothing.
     * @note Taking into account the above note, if SentryOptions.configureProfiling is not set,
     * calls to this method will always start a profile if one is not already running. This includes app
     * launch profiles configured with SentryOptions.enableAppLaunchProfiling .
     * @note If neither SentryOptions.profilesSampleRate nor SentryOptions.profilesSampler are
     * set, and SentryOptions.configureProfiling is set, this method does nothing if the profiling
     * session is not sampled with respect to SentryOptions.profileSessionSampleRate , or if it is
     * sampled but the profiler is already running.
     * @note If neither SentryOptions.profilesSampleRate nor SentryOptions.profilesSampler are
     * set, and SentryOptions.configureProfiling is set, this method does nothing if
     * SentryOptions.profileLifecycle is set to trace . In this scenario, the profiler is
     * automatically started and stopped depending on whether there is an active sampled span, so it is
     * not permitted to manually start profiling.
     * @note Profiling is automatically disabled if a thread sanitizer is attached.
     * @seealso https://docs.sentry.io/platforms/apple/guides/ios/profiling/#continuous-profiling
     */
    @objc public static func startProfiler() {
        SentrySDKInternal.startProfiler()
    }
    
    /**
     * Stop a continuous profiling session if there is one ongoing.
     * @warning Continuous profiling mode is experimental and may still contain bugs.
     * @note Does nothing if SentryOptions.profileLifecycle is set to trace .
     * @note Does not immediately stop the profiler. Profiling data is uploaded at regular timed
     * intervals; when the current interval completes, then the profiler stops and the data gathered
     * during that last interval is uploaded.
     * @note If a new call to startProfiler that would start the profiler is made before the last
     * interval completes, the profiler will continue running until another call to stop is made.
     * @note Profiling is automatically disabled if a thread sanitizer is attached.
     * @seealso https://docs.sentry.io/platforms/apple/guides/ios/profiling/#continuous-profiling
     */
    @objc public static func stopProfiler() {
        SentrySDKInternal.stopProfiler()
    }
    #endif

    // MARK: Internal

    // Conceptually internal but needs to be marked public with SPI for ObjC visibility
    @objc @_spi(Private) public static func clearLogger() {
        _loggerLock.synchronized {
            _logger = nil
        }
    }

    // MARK: Private
    
    private static var _loggerLock = NSLock()
    private static var _logger: SentryLogger?
}
// swiftlint:enable file_length
