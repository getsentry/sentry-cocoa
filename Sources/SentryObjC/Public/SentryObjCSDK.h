#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#    import "SentryObjCFeedbackSource.h"
#    import "SentryObjCLastRunStatus.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#    import <SentryObjC/SentryObjCFeedbackSource.h>
#    import <SentryObjC/SentryObjCLastRunStatus.h>
#endif

@class SentryObjCAttachment;
@class SentryObjCBreadcrumb;
@class SentryObjCEvent;
@class SentryObjCFeedbackApi;
@class SentryObjCId;
@class SentryObjCLogger;
@class SentryObjCMetricsApi;
@class SentryObjCOptions;
@class SentryObjCReplayApi;
@class SentryObjCScope;
@class SentryObjCSpan;
@class SentryObjCTransactionContext;
@class SentryObjCUser;

NS_ASSUME_NONNULL_BEGIN

/**
 * The main entry point for the Sentry SDK.
 * We recommend using @c startWithConfigureOptions: to initialize Sentry.
 */
@interface SentryObjCSDK : NSObject

/// The current active transaction or span bound to the scope.
@property (class, nonatomic, readonly, nullable) SentryObjCSpan *span;

/// Indicates whether the Sentry SDK is enabled.
@property (class, nonatomic, readonly) BOOL isEnabled;

/// API to access Sentry logs.
@property (class, nonatomic, readonly) SentryObjCLogger *logger;

/// API to record metrics (counters, distributions, gauges).
@property (class, nonatomic, readonly) SentryObjCMetricsApi *metrics;

/// API to access internal SDK features for hybrid SDKs (React Native, Flutter, .NET, Unity).
@property (class, nonatomic, readonly) SentryObjCInternalApi *internal;

/**
 * Returns the crash status of the last program execution.
 *
 * Before @c startWithOptions: finishes initializing the crash reporter,
 * this property returns @c SentryObjCLastRunStatusUnknown. After initialization it returns
 * either @c SentryObjCLastRunStatusDidCrash or @c SentryObjCLastRunStatusDidNotCrash.
 */
@property (class, nonatomic, readonly) SentryObjCLastRunStatus lastRunStatus;

/**
 * Checks if the SDK detected a start-up crash during SDK initialization.
 * @note The SDK init waits synchronously for up to 5 seconds to flush out events if the app
 * crashes within 2 seconds after the SDK init.
 */
@property (class, nonatomic, readonly) BOOL detectedStartUpCrash;

/**
 * Checks if the last program execution terminated with a crash.
 * @deprecated Use @c lastRunStatus instead.
 */
@property (class, nonatomic, readonly) BOOL crashedLastRun
    __attribute__((deprecated("Use lastRunStatus instead.")));

#if SENTRY_OBJC_REPLAY_SUPPORTED
/// API to control session replay.
@property (class, nonatomic, readonly) SentryObjCReplayApi *replay;
#endif

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT
/// The API for capturing user feedback.
@property (class, nonatomic, readonly) SentryObjCFeedbackApi *feedback;
#endif

/**
 * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations.
 * Make sure to set a valid DSN.
 * @param options The options to configure Sentry with.
 * @note Call this method on the main thread. When calling it from a background thread, the
 * SDK starts on the main thread async.
 */
+ (void)startWithOptions:(SentryObjCOptions *)options;

/**
 * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations.
 * Make sure to set a valid DSN.
 * @param configureOptions A block that configures the options.
 * @note Call this method on the main thread. When calling it from a background thread, the
 * SDK starts on the main thread async.
 */
+ (void)startWithConfigureOptions:(void (^)(SentryObjCOptions *))configureOptions;

/**
 * Captures a manually created event and sends it to Sentry.
 * @param event The event to send to Sentry.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureEvent:(SentryObjCEvent *)event;

/**
 * Captures a manually created event and sends it to Sentry. Only the data in this scope object
 * will be added to the event. The global scope will be ignored.
 * @param event The event to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureEvent:(SentryObjCEvent *)event withScope:(SentryObjCScope *)scope;

/**
 * Captures a manually created event and sends it to Sentry. Maintains the global scope but
 * mutates scope data for only this call.
 * @param event The event to send to Sentry.
 * @param block The block mutating the scope only for this call.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureEvent:(SentryObjCEvent *)event
                withScopeBlock:(void (^)(SentryObjCScope *))block;

/**
 * Captures a manually created event and sends it to Sentry, with a per-call override for
 * attaching all threads with stack traces.
 * @param event The event to send to Sentry.
 * @param attachAllThreads Whether to attach all threads with full stack traces.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureEvent:(SentryObjCEvent *)event attachAllThreads:(BOOL)attachAllThreads;

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param name The transaction name.
 * @param operation Short code identifying the type of operation the span is measuring.
 * @return The created transaction span.
 */
+ (SentryObjCSpan *)startTransactionWithName:(NSString *)name operation:(NSString *)operation;

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param name The transaction name.
 * @param operation Short code identifying the type of operation the span is measuring.
 * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
 * @return The created transaction span.
 */
+ (SentryObjCSpan *)startTransactionWithName:(NSString *)name
                                   operation:(NSString *)operation
                                 bindToScope:(BOOL)bindToScope;

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @return The created transaction span.
 */
+ (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext;

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
 * @return The created transaction span.
 */
+ (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                                    bindToScope:(BOOL)bindToScope;

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
 * @param customSamplingContext Additional information about the sampling context.
 * @return The created transaction span.
 */
+ (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                                    bindToScope:(BOOL)bindToScope
                          customSamplingContext:
                              (NSDictionary<NSString *, id> *)customSamplingContext;

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @param customSamplingContext Additional information about the sampling context.
 * @return The created transaction span.
 */
+ (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                          customSamplingContext:
                              (NSDictionary<NSString *, id> *)customSamplingContext;

/**
 * Captures an error event and sends it to Sentry.
 * @param error The error to send to Sentry.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureError:(NSError *)error;

/**
 * Captures an error event and sends it to Sentry. Only the data in this scope object will be
 * added to the event. The global scope will be ignored.
 * @param error The error to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureError:(NSError *)error withScope:(SentryObjCScope *)scope;

/**
 * Captures an error event and sends it to Sentry. Maintains the global scope but mutates scope
 * data for only this call.
 * @param error The error to send to Sentry.
 * @param block The block mutating the scope only for this call.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureError:(NSError *)error withScopeBlock:(void (^)(SentryObjCScope *))block;

/**
 * Captures an error event and sends it to Sentry, with a per-call override for attaching all
 * threads with stack traces.
 * @param error The error to send to Sentry.
 * @param attachAllThreads Whether to attach all threads with full stack traces.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureError:(NSError *)error attachAllThreads:(BOOL)attachAllThreads;

/**
 * Captures an exception event and sends it to Sentry.
 * @param exception The exception to send to Sentry.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureException:(NSException *)exception;

/**
 * Captures an exception event and sends it to Sentry. Only the data in this scope object will be
 * added to the event. The global scope will be ignored.
 * @param exception The exception to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureException:(NSException *)exception withScope:(SentryObjCScope *)scope;

/**
 * Captures an exception event and sends it to Sentry. Maintains the global scope but mutates
 * scope data for only this call.
 * @param exception The exception to send to Sentry.
 * @param block The block mutating the scope only for this call.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureException:(NSException *)exception
                    withScopeBlock:(void (^)(SentryObjCScope *))block;

/**
 * Captures an exception event and sends it to Sentry, with a per-call override for attaching
 * all threads with stack traces.
 * @param exception The exception to send to Sentry.
 * @param attachAllThreads Whether to attach all threads with full stack traces.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureException:(NSException *)exception attachAllThreads:(BOOL)attachAllThreads;

/**
 * Captures a message event and sends it to Sentry.
 * @param message The message to send to Sentry.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureMessage:(NSString *)message;

/**
 * Captures a message event and sends it to Sentry. Only the data in this scope object will be
 * added to the event. The global scope will be ignored.
 * @param message The message to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureMessage:(NSString *)message withScope:(SentryObjCScope *)scope;

/**
 * Captures a message event and sends it to Sentry. Maintains the global scope but mutates scope
 * data for only this call.
 * @param message The message to send to Sentry.
 * @param block The block mutating the scope only for this call.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureMessage:(NSString *)message
                  withScopeBlock:(void (^)(SentryObjCScope *))block;

/**
 * Captures a message event and sends it to Sentry, with a per-call override for attaching all
 * threads with stack traces.
 * @param message The message to send to Sentry.
 * @param attachAllThreads Whether to attach all threads with full stack traces.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
+ (SentryObjCId *)captureMessage:(NSString *)message attachAllThreads:(BOOL)attachAllThreads;

/**
 * Captures user feedback and sends it to Sentry.
 * @param message The feedback message.
 * @param name The name of the user providing feedback (optional).
 * @param email The email of the user providing feedback (optional).
 * @param source The source of the feedback.
 * @param associatedEventId The event ID to associate with this feedback (optional).
 * @param attachments Attachments to include with the feedback (optional).
 */
+ (void)captureFeedbackWithMessage:(NSString *)message
                              name:(nullable NSString *)name
                             email:(nullable NSString *)email
                            source:(SentryObjCFeedbackSource)source
                 associatedEventId:(nullable SentryObjCId *)associatedEventId
                       attachments:(nullable NSArray<SentryObjCAttachment *> *)attachments;

/**
 * Adds a @c Breadcrumb to the current @c Scope of the current @c Hub. If the total number of
 * breadcrumbs exceeds the @c maxBreadcrumbs option, the SDK removes the oldest breadcrumb.
 * @param crumb The @c Breadcrumb to add to the current @c Scope.
 */
+ (void)addBreadcrumb:(SentryObjCBreadcrumb *)crumb;

/**
 * Use this method to modify the current @c Scope of the current @c Hub. The SDK uses the
 * @c Scope to attach contextual data to events.
 * @param callback The callback for configuring the current @c Scope.
 */
+ (void)configureScope:(void (^)(SentryObjCScope *))callback;

/**
 * Set user to the current @c Scope of the current @c Hub.
 * @param user The user to set to the current @c Scope.
 * @note You must start the SDK before calling this method, otherwise it doesn't set the user.
 */
+ (void)setUser:(nullable SentryObjCUser *)user;

/**
 * Starts a new @c SentrySession. If there's a running session, it ends it before starting the
 * new one. You can use this method in combination with @c endSession to manually track sessions.
 */
+ (void)startSession;

/**
 * Ends the current @c SentrySession. You can use this method in combination with
 * @c startSession to manually track sessions.
 */
+ (void)endSession;

/**
 * This forces a crash, useful to test the SentryCrash integration.
 * @note The SDK can't report a crash when a debugger is attached. Your application needs to run
 * without a debugger attached to capture the crash and send it to Sentry the next time you
 * launch your application.
 */
+ (void)crash;

/**
 * Reports to the ongoing UIViewController transaction that the screen contents are fully loaded
 * and displayed, which will create a new span.
 * @see
 * https://docs.sentry.io/platforms/cocoa/performance/instrumentation/automatic-instrumentation/#time-to-full-display
 */
+ (void)reportFullyDisplayed;

/**
 * Pauses sending detected app hangs to Sentry.
 * @note This method doesn't close the detection of app hangs. Instead, the app hang detection
 * will ignore detected app hangs until you call @c resumeAppHangTracking.
 */
+ (void)pauseAppHangTracking;

/// Resumes sending detected app hangs to Sentry.
+ (void)resumeAppHangTracking;

/**
 * Waits synchronously for the SDK to flush out all queued and cached items for up to the
 * specified timeout in seconds. If there is no internet connection, the function returns
 * immediately. The SDK doesn't dispose the client or the hub.
 * @param timeout The time to wait for the SDK to complete the flush.
 */
+ (void)flush:(NSTimeInterval)timeout;

/**
 * Closes the SDK, uninstalls all the integrations, and calls flush with
 * @c shutdownTimeInterval.
 */
+ (void)close;

#if !(TARGET_OS_WATCH || TARGET_OS_TV || TARGET_OS_VISION)
/**
 * Start a new continuous profiling session if one is not already running.
 * @warning Continuous profiling mode is experimental and may still contain bugs.
 * @note Profiling is automatically disabled if a thread sanitizer is attached.
 */
+ (void)startProfiler;

/**
 * Stop a continuous profiling session if there is one ongoing.
 * @warning Continuous profiling mode is experimental and may still contain bugs.
 * @note Does not immediately stop the profiler. Profiling data is uploaded at regular timed
 * intervals; when the current interval completes, then the profiler stops.
 * @note Profiling is automatically disabled if a thread sanitizer is attached.
 */
+ (void)stopProfiler;
#endif

@end

NS_ASSUME_NONNULL_END
