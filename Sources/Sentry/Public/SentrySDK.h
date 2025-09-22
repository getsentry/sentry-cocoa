#if !SDK_V9

#    import <Foundation/Foundation.h>

@class SentryOptions;
@class SentryEvent;
@class SentryScope;
@class SentryId;
@class SentryTransactionContext;
@class SentryUserFeedback;
@class SentryUser;
@class SentryFeedback;
@class SentryBreadcrumb;
@class SentryReplayApi;
@class SentryLogger;
@class SentryUser;
@class SentryFeedbackAPI;

@protocol SentrySpan;

@interface SentrySDK : NSObject

@property (nullable, class, nonatomic, readonly) id<SentrySpan> span;

/// Indicates whether the Sentry SDK is enabled.
@property (class, nonatomic, readonly) BOOL isEnabled;

#    if SENTRY_TARGET_REPLAY_SUPPORTED
/**
 * API to control session replay
 */
@property (class, nonatomic, readonly) SentryReplayApi *_Nonnull replay;
#    endif

/// API to access Sentry logs
@property (class, nonatomic, readonly) SentryLogger *_Nonnull logger;

/// Inits and configures Sentry (<code>SentryHub</code>, <code>SentryClient</code>) and sets up all
/// integrations. Make sure to set a valid DSN. note: Call this method on the main thread. When
/// calling it from a background thread, the SDK starts on the main thread async.
+ (void)startWithOptions:(SentryOptions *_Nonnull)options NS_SWIFT_NAME(start(options:));

/// Inits and configures Sentry (<code>SentryHub</code>, <code>SentryClient</code>) and sets up all
/// integrations. Make sure to set a valid DSN. note: Call this method on the main thread. When
/// calling it from a background thread, the SDK starts on the main thread async.
+ (void)startWithConfigureOptions:(void (^_Nonnull)(SentryOptions *_Nonnull))configureOptions
    NS_SWIFT_NAME(start(configureOptions:));

/// Captures a manually created event and sends it to Sentry.
/// \param event The event to send to Sentry.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureEvent:(SentryEvent *_Nonnull)event NS_SWIFT_NAME(capture(event:));

/// Captures a manually created event and sends it to Sentry. Only the data in this scope object
/// will be added to the event. The global scope will be ignored.
/// \param event The event to send to Sentry.
///
/// \param scope The scope containing event metadata.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureEvent:(SentryEvent *_Nonnull)event
                         withScope:(SentryScope *_Nonnull)scope
    NS_SWIFT_NAME(capture(event:scope:));

/// Captures a manually created event and sends it to Sentry. Maintains the global scope but mutates
/// scope data for only this call.
/// \param event The event to send to Sentry.
///
/// \param block The block mutating the scope only for this call.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureEvent:(SentryEvent *_Nonnull)event
                    withScopeBlock:(void (^_Nonnull)(SentryScope *_Nonnull))block
    NS_SWIFT_NAME(capture(event:block:));

/// Creates a transaction, binds it to the hub and returns the instance.
/// \param name The transaction name.
///
/// \param operation Short code identifying the type of operation the span is measuring.
///
///
/// returns:
/// The created transaction.
+ (id<SentrySpan> _Nonnull)startTransactionWithName:(NSString *_Nonnull)name
                                          operation:(NSString *_Nonnull)operation
    NS_SWIFT_NAME(startTransaction(name:operation:));

/// Creates a transaction, binds it to the hub and returns the instance.
/// \param name The transaction name.
///
/// \param operation Short code identifying the type of operation the span is measuring.
///
/// \param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
///
///
/// returns:
/// The created transaction.
+ (id<SentrySpan> _Nonnull)startTransactionWithName:(NSString *_Nonnull)name
                                          operation:(NSString *_Nonnull)operation
                                        bindToScope:(BOOL)bindToScope
    NS_SWIFT_NAME(startTransaction(name:operation:bindToScope:));

/// Creates a transaction, binds it to the hub and returns the instance.
/// \param transactionContext The transaction context.
///
///
/// returns:
/// The created transaction.
+ (id<SentrySpan> _Nonnull)startTransactionWithContext:
    (SentryTransactionContext *_Nonnull)transactionContext
    NS_SWIFT_NAME(startTransaction(transactionContext:));

/// Creates a transaction, binds it to the hub and returns the instance.
/// \param transactionContext The transaction context.
///
/// \param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
///
///
/// returns:
/// The created transaction.
+ (id<SentrySpan> _Nonnull)startTransactionWithContext:
                               (SentryTransactionContext *_Nonnull)transactionContext
                                           bindToScope:(BOOL)bindToScope
    NS_SWIFT_NAME(startTransaction(transactionContext:bindToScope:));

/// Creates a transaction, binds it to the hub and returns the instance.
/// \param transactionContext The transaction context.
///
/// \param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
///
/// \param customSamplingContext Additional information about the sampling context.
///
///
/// returns:
/// The created transaction.
+ (id<SentrySpan> _Nonnull)
    startTransactionWithContext:(SentryTransactionContext *_Nonnull)transactionContext
                    bindToScope:(BOOL)bindToScope
          customSamplingContext:(NSDictionary<NSString *, id> *_Nonnull)customSamplingContext
    NS_SWIFT_NAME(startTransaction(transactionContext:bindToScope:customSamplingContext:));

/// Creates a transaction, binds it to the hub and returns the instance.
/// \param transactionContext The transaction context.
///
/// \param customSamplingContext Additional information about the sampling context.
///
///
/// returns:
/// The created transaction.
+ (id<SentrySpan> _Nonnull)
    startTransactionWithContext:(SentryTransactionContext *_Nonnull)transactionContext
          customSamplingContext:(NSDictionary<NSString *, id> *_Nonnull)customSamplingContext
    NS_SWIFT_NAME(startTransaction(transactionContext:customSamplingContext:));

/// Captures an error event and sends it to Sentry.
/// \param error The error to send to Sentry.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureError:(NSError *_Nonnull)error NS_SWIFT_NAME(capture(error:));

/// Captures an error event and sends it to Sentry. Only the data in this scope object will be added
/// to the event. The global scope will be ignored.
/// \param error The error to send to Sentry.
///
/// \param scope The scope containing event metadata.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureError:(NSError *_Nonnull)error
                         withScope:(SentryScope *_Nonnull)scope
    NS_SWIFT_NAME(capture(error:scope:));

/// Captures an error event and sends it to Sentry. Maintains the global scope but mutates scope
/// data for only this call.
/// \param error The error to send to Sentry.
///
/// \param block The block mutating the scope only for this call.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureError:(NSError *_Nonnull)error
                    withScopeBlock:(void (^_Nonnull)(SentryScope *_Nonnull))block
    NS_SWIFT_NAME(capture(error:block:));

/// Captures an exception event and sends it to Sentry.
/// \param exception The exception to send to Sentry.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureException:(NSException *_Nonnull)exception
    NS_SWIFT_NAME(capture(exception:));

/// Captures an exception event and sends it to Sentry. Only the data in this scope object will be
/// added to the event. The global scope will be ignored.
/// \param exception The exception to send to Sentry.
///
/// \param scope The scope containing event metadata.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureException:(NSException *_Nonnull)exception
                             withScope:(SentryScope *_Nonnull)scope
    NS_SWIFT_NAME(capture(exception:scope:));

/// Captures an exception event and sends it to Sentry. Maintains the global scope but mutates scope
/// data for only this call.
/// \param exception The exception to send to Sentry.
///
/// \param block The block mutating the scope only for this call.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureException:(NSException *_Nonnull)exception
                        withScopeBlock:(void (^_Nonnull)(SentryScope *_Nonnull))block
    NS_SWIFT_NAME(capture(exception:block:));

/// Captures a message event and sends it to Sentry.
/// \param message The message to send to Sentry.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureMessage:(NSString *_Nonnull)message NS_SWIFT_NAME(capture(message:));

/// Captures a message event and sends it to Sentry. Only the data in this scope object will be
/// added to the event. The global scope will be ignored.
/// \param message The message to send to Sentry.
///
/// \param scope The scope containing event metadata.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureMessage:(NSString *_Nonnull)message
                           withScope:(SentryScope *_Nonnull)scope
    NS_SWIFT_NAME(capture(message:scope:));

/// Captures a message event and sends it to Sentry. Maintains the global scope but mutates scope
/// data for only this call.
/// \param message The message to send to Sentry.
///
/// \param block The block mutating the scope only for this call.
///
///
/// returns:
/// The <code>SentryId</code> of the event or <code>SentryId.empty</code> if the event is not sent.
+ (SentryId *_Nonnull)captureMessage:(NSString *_Nonnull)message
                      withScopeBlock:(void (^_Nonnull)(SentryScope *_Nonnull))block
    NS_SWIFT_NAME(capture(message:block:));

/// Captures user feedback that was manually gathered and sends it to Sentry.
/// \param userFeedback The user feedback to send to Sentry.
///
+ (void)captureUserFeedback:(SentryUserFeedback *_Nonnull)userFeedback
    NS_SWIFT_NAME(capture(userFeedback:))
        DEPRECATED_MSG_ATTRIBUTE("Use SentrySDK.back or use or configure our new managed UX with "
                                 "SentryOptions.configureUserFeedback.");

/// Captures user feedback that was manually gathered and sends it to Sentry.
/// warning:
/// This is an experimental feature and may still have bugs.
/// note:
/// If you’d prefer not to have to build the UI required to gather the feedback from the user,
/// see <code>SentryOptions.configureUserFeedback</code> to customize a fully managed integration.
/// See https://docs.sentry.io/platforms/apple/user-feedback/ for more information.
/// \param feedback The feedback to send to Sentry.
///
+ (void)captureFeedback:(SentryFeedback *_Nonnull)feedback NS_SWIFT_NAME(capture(feedback:));

#    if TARGET_OS_IOS && SENTRY_HAS_UIKIT

@property (nonatomic, class, readonly)
    SentryFeedbackAPI *_Nonnull feedback NS_EXTENSION_UNAVAILABLE(
        "Sentry User Feedback UI cannot be used from app extensions.");

#    endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

/// Adds a <code>Breadcrumb</code> to the current <code>Scope</code> of the current
/// <code>Hub</code>. If the total number of breadcrumbs exceeds the
/// <code>SentryOptions.maxBreadcrumbs</code> the SDK removes the oldest breadcrumb.
/// \param crumb The <code>Breadcrumb</code> to add to the current <code>Scope</code> of the current
/// <code>Hub</code>.
///
+ (void)addBreadcrumb:(SentryBreadcrumb *_Nonnull)crumb NS_SWIFT_NAME(addBreadcrumb(_:));

/// Use this method to modify the current <code>Scope</code> of the current <code>Hub</code>. The
/// SDK uses the <code>Scope</code> to attach contextual data to events.
/// \param callback The callback for configuring the current <code>Scope</code> of the current
/// <code>Hub</code>.
///
+ (void)configureScope:(void (^_Nonnull)(SentryScope *_Nonnull))callback;

/// Checks if the last program execution terminated with a crash.
+ (BOOL)crashedLastRun;

/// Checks if the SDK detected a start-up crash during SDK initialization.
/// note:
/// The SDK init waits synchronously for up to 5 seconds to flush out events if the app crashes
/// within 2 seconds after the SDK init.
///
/// returns:
/// true if the SDK detected a start-up crash and false if not.
+ (BOOL)detectedStartUpCrash;

/// Set <code>user</code> to the current <code>Scope</code> of the current <code>Hub</code>.
/// note:
/// You must start the SDK before calling this method, otherwise it doesn’t set the user.
/// \param user The user to set to the current <code>Scope</code>.
///
+ (void)setUser:(SentryUser *_Nullable)user;

/// Starts a new <code>SentrySession</code>. If there’s a running <code>SentrySession</code>, it
/// ends it before starting the new one. You can use this method in combination with
/// <code>endSession</code> to manually track sessions. The SDK uses <code>SentrySession</code> to
/// inform Sentry about release and project associated project health.
+ (void)startSession;

/// Ends the current <code>SentrySession</code>. You can use this method in combination with
/// <code>startSession</code> to manually track <code>SentrySessions</code>. The SDK uses
/// <code>SentrySession</code> to inform Sentry about release and project associated project health.
+ (void)endSession;

/// This forces a crash, useful to test the <code>SentryCrash</code> integration.
/// note:
/// The SDK can’t report a crash when a debugger is attached. Your application needs to run
/// without a debugger attached to capture the crash and send it to Sentry the next time you launch
/// your application.
+ (void)crash;

/// Reports to the ongoing <code>UIViewController</code> transaction
/// that the screen contents are fully loaded and displayed,
/// which will create a new span.
/// seealso:
///
/// https://docs.sentry.io/platforms/cocoa/performance/instrumentation/automatic-instrumentation/#time-to-full-display
+ (void)reportFullyDisplayed;

/// Pauses sending detected app hangs to Sentry.
/// This method doesn’t close the detection of app hangs. Instead, the app hang detection
/// will ignore detected app hangs until you call <code>resumeAppHangTracking</code>.
+ (void)pauseAppHangTracking;

/// Resumes sending detected app hangs to Sentry.
+ (void)resumeAppHangTracking;

/// Waits synchronously for the SDK to flush out all queued and cached items for up to the specified
/// timeout in seconds. If there is no internet connection, the function returns immediately. The
/// SDK doesn’t dispose the client or the hub. note: This might take slightly longer than the
/// specified timeout if there are many batched logs to capture.
/// \param timeout The time to wait for the SDK to complete the flush.
///
+ (void)flush:(NSTimeInterval)timeout NS_SWIFT_NAME(flush(timeout:));

/// Closes the SDK, uninstalls all the integrations, and calls <code>flush</code> with
/// <code>SentryOptions.shutdownTimeInterval</code>.
+ (void)close;

/// Start a new continuous profiling session if one is not already running.
/// warning:
/// Continuous profiling mode is experimental and may still contain bugs.
/// note:
/// Unlike transaction-based profiling, continuous profiling does not take into account
/// <code>SentryOptions.profilesSampleRate</code> or <code>SentryOptions.profilesSampler</code>. If
/// either of those options are set, this method does nothing. note: Taking into account the above
/// note, if <code>SentryOptions.configureProfiling</code> is not set, calls to this method will
/// always start a profile if one is not already running. This includes app launch profiles
/// configured with <code>SentryOptions.enableAppLaunchProfiling</code>. note: If neither
/// <code>SentryOptions.profilesSampleRate</code> nor <code>SentryOptions.profilesSampler</code> are
/// set, and <code>SentryOptions.configureProfiling</code> is set, this method does nothing if the
/// profiling session is not sampled with respect to
/// <code>SentryOptions.profileSessionSampleRate</code>, or if it is sampled but the profiler is
/// already running. note: If neither <code>SentryOptions.profilesSampleRate</code> nor
/// <code>SentryOptions.profilesSampler</code> are set, and
/// <code>SentryOptions.configureProfiling</code> is set, this method does nothing if
/// <code>SentryOptions.profileLifecycle</code> is set to <code>trace</code>. In this scenario, the
/// profiler is automatically started and stopped depending on whether there is an active sampled
/// span, so it is not permitted to manually start profiling. note: Profiling is automatically
/// disabled if a thread sanitizer is attached. seealso:
/// https://docs.sentry.io/platforms/apple/guides/ios/profiling/#continuous-profiling
+ (void)startProfiler;

/// Stop a continuous profiling session if there is one ongoing.
/// warning:
/// Continuous profiling mode is experimental and may still contain bugs.
/// note:
/// Does nothing if <code>SentryOptions.profileLifecycle</code> is set to <code>trace</code>.
/// note:
/// Does not immediately stop the profiler. Profiling data is uploaded at regular timed
/// intervals; when the current interval completes, then the profiler stops and the data gathered
/// during that last interval is uploaded.
/// note:
/// If a new call to <code>startProfiler</code> that would start the profiler is made before the
/// last interval completes, the profiler will continue running until another call to stop is made.
/// note:
/// Profiling is automatically disabled if a thread sanitizer is attached.
/// seealso:
/// https://docs.sentry.io/platforms/apple/guides/ios/profiling/#continuous-profiling
+ (void)stopProfiler;

@end

#endif // !SDK_V9
