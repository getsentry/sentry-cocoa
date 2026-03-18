#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

@class SentryBreadcrumb;
@class SentryEvent;
@class SentryId;
@class SentryOptions;
@class SentryScope;
@class SentryTransactionContext;
@class SentryFeedback;
@class SentryUser;
@protocol SentrySpan;

#if SENTRY_OBJC_REPLAY_SUPPORTED
@class SentryReplayApi;
#endif

@class SentryLogger;
@protocol SentryObjCMetricsApi;

NS_ASSUME_NONNULL_BEGIN

/**
 * Main entry point for the Sentry SDK (Objective-C wrapper).
 *
 * This is a pure Objective-C wrapper around the Sentry SDK that works in
 * projects with CLANG_ENABLE_MODULES=NO. Use this class to initialize the
 * SDK, capture events, and manage SDK state.
 *
 * @see SentryOptions
 * @see SentryScope
 */
@interface SentryObjCSDK : NSObject

SENTRY_NO_INIT

/**
 * Returns the currently active span or transaction.
 *
 * @return The active span, or @c nil if no span is active.
 */
+ (nullable id<SentrySpan>)span;

/**
 * Indicates whether the SDK has been properly initialized and is enabled.
 *
 * @return @c YES if the SDK is enabled, @c NO otherwise.
 */
+ (BOOL)isEnabled;

#if SENTRY_OBJC_REPLAY_SUPPORTED
/**
 * Returns the Session Replay API for controlling replay recording.
 *
 * @return The replay API instance.
 */
+ (SentryReplayApi *)replay;
#endif

/**
 * Returns the SDK logger instance.
 *
 * @return The logger instance.
 */
+ (SentryLogger *)logger;

/**
 * Returns the Metrics API for recording custom metrics.
 *
 * Sentry Metrics allows you to send counters, gauges, and distributions from your applications
 * to Sentry. Once in Sentry, these metrics can be viewed alongside related errors, traces, and
 * logs.
 *
 * @return The metrics API instance.
 *
 * @code
 * // Simple counter
 * [[SentryObjCSDK metrics] countWithKey:@"button.click"];
 *
 * // Distribution with unit and attributes
 * [[SentryObjCSDK metrics] distributionWithKey:@"response.time"
 *                                         value:125.5
 *                                          unit:SentryUnitNameMillisecond
 *                                    attributes:@{
 *     @"endpoint": [SentryObjCAttributeContent stringWithValue:@"/api/data"]
 * }];
 * @endcode
 *
 * @see SentryObjCMetricsApi
 */
+ (id<SentryObjCMetricsApi>)metrics;

/**
 * Initializes the SDK with the provided options.
 *
 * Call this method once during application startup.
 *
 * @param options The configuration options for the SDK.
 */
+ (void)startWithOptions:(SentryOptions *)options;

/**
 * Initializes the SDK with a configuration block.
 *
 * This is a convenience method that creates default options and passes them
 * to the configuration block for customization.
 *
 * @param configureOptions A block that receives the options object for configuration.
 */
+ (void)startWithConfigureOptions:(void (^)(SentryOptions *options))configureOptions;

/**
 * Captures an event and sends it to Sentry.
 *
 * @param event The event to capture.
 * @return The event ID of the captured event.
 */
+ (SentryId *)captureEvent:(SentryEvent *)event;

/**
 * Captures an event with a specific scope and sends it to Sentry.
 *
 * @param event The event to capture.
 * @param scope The scope to use for this event.
 * @return The event ID of the captured event.
 */
+ (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope;

/**
 * Captures an event with a scope modification block.
 *
 * The block allows you to modify the scope for this specific event capture.
 *
 * @param event The event to capture.
 * @param block A block that receives the scope for modification.
 * @return The event ID of the captured event.
 */
+ (SentryId *)captureEvent:(SentryEvent *)event withScopeBlock:(void (^)(SentryScope *scope))block;

/**
 * Starts a new transaction for performance monitoring.
 *
 * @param name The name of the transaction.
 * @param operation The operation type (e.g., "http.server", "db.query").
 * @return The started transaction span.
 */
+ (id<SentrySpan>)startTransactionWithName:(NSString *)name operation:(NSString *)operation;

/**
 * Starts a new transaction with scope binding control.
 *
 * @param name The name of the transaction.
 * @param operation The operation type.
 * @param bindToScope If @c YES, binds the transaction to the current scope.
 * @return The started transaction span.
 */
+ (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                 operation:(NSString *)operation
                               bindToScope:(BOOL)bindToScope;

/**
 * Starts a new transaction from a transaction context.
 *
 * @param transactionContext The transaction context containing name, operation, and trace
 * information.
 * @return The started transaction span.
 */
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext;

/**
 * Starts a new transaction from a transaction context with scope binding control.
 *
 * @param transactionContext The transaction context.
 * @param bindToScope If @c YES, binds the transaction to the current scope.
 * @return The started transaction span.
 */
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope;

/**
 * Starts a new transaction with custom sampling context.
 *
 * @param transactionContext The transaction context.
 * @param customSamplingContext Additional data to pass to the traces sampler callback.
 * @return The started transaction span.
 */
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

/**
 * Starts a new transaction with full control over binding and sampling.
 *
 * @param transactionContext The transaction context.
 * @param bindToScope If @c YES, binds the transaction to the current scope.
 * @param customSamplingContext Additional data to pass to the traces sampler callback.
 * @return The started transaction span.
 */
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

/**
 * Captures an @c NSError and sends it to Sentry.
 *
 * @param error The error to capture.
 * @return The event ID of the captured error.
 */
+ (SentryId *)captureError:(NSError *)error;

/**
 * Captures an @c NSError with a specific scope.
 *
 * @param error The error to capture.
 * @param scope The scope to use for this error.
 * @return The event ID of the captured error.
 */
+ (SentryId *)captureError:(NSError *)error withScope:(SentryScope *)scope;

/**
 * Captures an @c NSError with a scope modification block.
 *
 * @param error The error to capture.
 * @param block A block that receives the scope for modification.
 * @return The event ID of the captured error.
 */
+ (SentryId *)captureError:(NSError *)error withScopeBlock:(void (^)(SentryScope *scope))block;

/**
 * Captures an @c NSException and sends it to Sentry.
 *
 * @param exception The exception to capture.
 * @return The event ID of the captured exception.
 */
+ (SentryId *)captureException:(NSException *)exception;

/**
 * Captures an @c NSException with a specific scope.
 *
 * @param exception The exception to capture.
 * @param scope The scope to use for this exception.
 * @return The event ID of the captured exception.
 */
+ (SentryId *)captureException:(NSException *)exception withScope:(SentryScope *)scope;

/**
 * Captures an @c NSException with a scope modification block.
 *
 * @param exception The exception to capture.
 * @param block A block that receives the scope for modification.
 * @return The event ID of the captured exception.
 */
+ (SentryId *)captureException:(NSException *)exception
                withScopeBlock:(void (^)(SentryScope *scope))block;

/**
 * Captures a message string and sends it to Sentry.
 *
 * @param message The message to capture.
 * @return The event ID of the captured message.
 */
+ (SentryId *)captureMessage:(NSString *)message;

/**
 * Captures a message with a specific scope.
 *
 * @param message The message to capture.
 * @param scope The scope to use for this message.
 * @return The event ID of the captured message.
 */
+ (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope;

/**
 * Captures a message with a scope modification block.
 *
 * @param message The message to capture.
 * @param block A block that receives the scope for modification.
 * @return The event ID of the captured message.
 */
+ (SentryId *)captureMessage:(NSString *)message withScopeBlock:(void (^)(SentryScope *scope))block;

/**
 * Captures user feedback and sends it to Sentry.
 *
 * @param feedback The user feedback to capture.
 */
+ (void)captureFeedback:(SentryFeedback *)feedback;

/**
 * Adds a breadcrumb to the current scope.
 *
 * Breadcrumbs are sent with subsequent error events to provide context.
 *
 * @param crumb The breadcrumb to add.
 */
+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

/**
 * Modifies the current scope using a callback block.
 *
 * Use this to add tags, extra data, or other contextual information.
 *
 * @param callback A block that receives the current scope for modification.
 */
+ (void)configureScope:(void (^)(SentryScope *scope))callback;

/**
 * Indicates whether the application crashed during the last run.
 *
 * @return @c YES if the app crashed on the previous run, @c NO otherwise.
 */
+ (BOOL)crashedLastRun;

/**
 * Indicates whether a startup crash was detected.
 *
 * A startup crash is one that occurred shortly after app launch.
 *
 * @return @c YES if a startup crash was detected, @c NO otherwise.
 */
+ (BOOL)detectedStartUpCrash;

/**
 * Sets the user information for the current scope.
 *
 * @param user The user information, or @c nil to clear the current user.
 */
+ (void)setUser:(nullable SentryUser *)user;

/**
 * Manually starts a new session.
 *
 * Sessions are typically started automatically, but this method allows manual control.
 */
+ (void)startSession;

/**
 * Manually ends the current session.
 */
+ (void)endSession;

/**
 * Triggers a crash for testing purposes.
 *
 * @warning This method will terminate the application. Use only for testing.
 */
+ (void)crash;

/**
 * Reports that the application is now fully displayed to the user.
 *
 * Used for Time To Full Display tracking.
 */
+ (void)reportFullyDisplayed;

/**
 * Pauses app hang tracking.
 *
 * Use this when performing known long-running operations on the main thread
 * that should not be reported as app hangs.
 */
+ (void)pauseAppHangTracking;

/**
 * Resumes app hang tracking after it was paused.
 */
+ (void)resumeAppHangTracking;

/**
 * Waits for all pending events to be sent to Sentry.
 *
 * @param timeout Maximum time to wait in seconds.
 */
+ (void)flush:(NSTimeInterval)timeout;

/**
 * Shuts down the SDK and releases resources.
 *
 * After calling this method, the SDK will no longer capture events.
 */
+ (void)close;

#if !(TARGET_OS_WATCH || TARGET_OS_TV || TARGET_OS_VISION)
/**
 * Manually starts the profiler.
 *
 * Profiling is typically controlled automatically by sampling, but this
 * method allows manual control for testing or specific use cases.
 */
+ (void)startProfiler;

/**
 * Manually stops the profiler.
 */
+ (void)stopProfiler;
#endif

@end

NS_ASSUME_NONNULL_END
