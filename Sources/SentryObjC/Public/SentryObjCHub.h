#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCClient;
@class SentryObjCEvent;
@class SentryObjCScope;
@class SentryObjCId;
@class SentryObjCBreadcrumb;
@class SentryObjCUser;
@class SentryObjCFeedback;
@class SentryObjCSpan;
@class SentryObjCTransactionContext;

NS_ASSUME_NONNULL_BEGIN

/// The hub is the central manager for SDK configuration, error capture, and scope management.
@interface SentryObjCHub : NSObject
SENTRY_NO_INIT

/**
 * Initializes a @c SentryObjCHub with the given client and scope.
 * @param client The client to bind to the hub.
 * @param scope The scope to use for the hub.
 */
- (instancetype)initWithClient:(SentryObjCClient *_Nullable)client
                      andScope:(SentryObjCScope *_Nullable)scope;

/**
 * Starts a new @c SentrySession. If there's a running session, it ends it before starting the
 * new one. You can use this method in combination with @c endSession to manually track sessions.
 */
- (void)startSession;

/**
 * Ends the current @c SentrySession. You can use this method in combination with @c startSession
 * to manually track sessions.
 */
- (void)endSession;

/**
 * Ends the current session with the given timestamp.
 * @param timestamp The timestamp to end the session with.
 */
- (void)endSessionWithTimestamp:(NSDate *)timestamp;

/**
 * Captures a manually created event and sends it to Sentry.
 * @param event The event to send to Sentry.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
- (SentryObjCId *)captureEvent:(SentryObjCEvent *)event NS_SWIFT_NAME(capture(event:));

/**
 * Captures a manually created event and sends it to Sentry.
 * @param event The event to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
- (SentryObjCId *)captureEvent:(SentryObjCEvent *)event
                     withScope:(SentryObjCScope *)scope NS_SWIFT_NAME(capture(event:scope:));

/**
 * Captures an error event and sends it to Sentry.
 * @param error The error to send to Sentry.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
- (SentryObjCId *)captureError:(NSError *)error NS_SWIFT_NAME(capture(error:));

/**
 * Captures an error event and sends it to Sentry.
 * @param error The error to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
- (SentryObjCId *)captureError:(NSError *)error
                     withScope:(SentryObjCScope *)scope NS_SWIFT_NAME(capture(error:scope:));

/**
 * Captures an exception event and sends it to Sentry.
 * @param exception The exception to send to Sentry.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
- (SentryObjCId *)captureException:(NSException *)exception NS_SWIFT_NAME(capture(exception:));

/**
 * Captures an exception event and sends it to Sentry.
 * @param exception The exception to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
- (SentryObjCId *)captureException:(NSException *)exception
                         withScope:(SentryObjCScope *)scope
    NS_SWIFT_NAME(capture(exception:scope:));

/**
 * Captures a message event and sends it to Sentry.
 * @param message The message to send to Sentry.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
- (SentryObjCId *)captureMessage:(NSString *)message NS_SWIFT_NAME(capture(message:));

/**
 * Captures a message event and sends it to Sentry.
 * @param message The message to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryObjCId of the event or an empty ID if the event is not sent.
 */
- (SentryObjCId *)captureMessage:(NSString *)message
                       withScope:(SentryObjCScope *)scope NS_SWIFT_NAME(capture(message:scope:));

/**
 * Captures user feedback and sends it to Sentry.
 * @param feedback The user feedback to send to Sentry.
 */
- (void)captureFeedback:(SentryObjCFeedback *)feedback NS_SWIFT_NAME(capture(feedback:));

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param name The transaction name.
 * @param operation Short code identifying the type of operation the span is measuring.
 * @return The created transaction span.
 */
- (SentryObjCSpan *)startTransactionWithName:(NSString *)name operation:(NSString *)operation;

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param name The transaction name.
 * @param operation Short code identifying the type of operation the span is measuring.
 * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
 * @return The created transaction span.
 */
- (SentryObjCSpan *)startTransactionWithName:(NSString *)name
                                   operation:(NSString *)operation
                                 bindToScope:(BOOL)bindToScope;

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @return The created transaction span.
 */
- (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext;

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
 * @return The created transaction span.
 */
- (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                                    bindToScope:(BOOL)bindToScope;

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
 * @param customSamplingContext Additional information about the sampling context.
 * @return The created transaction span.
 */
- (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                                    bindToScope:(BOOL)bindToScope
                          customSamplingContext:
                              (NSDictionary<NSString *, id> *)customSamplingContext;

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @param customSamplingContext Additional information about the sampling context.
 * @return The created transaction span.
 */
- (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                          customSamplingContext:
                              (NSDictionary<NSString *, id> *)customSamplingContext;

/**
 * Use this method to modify the @c Scope of the Hub. The SDK uses the @c Scope to attach
 * contextual data to events.
 * @param callback The callback for configuring the @c Scope of the Hub.
 */
- (void)configureScope:(void (^)(SentryObjCScope *))callback;

/**
 * Adds a breadcrumb to the @c Scope of the Hub.
 * @param crumb The @c Breadcrumb to add to the @c Scope of the Hub.
 */
- (void)addBreadcrumb:(SentryObjCBreadcrumb *)crumb;

/**
 * Adds a feature flag evaluation to the @c Scope of the Hub.
 * @param name The feature flag name.
 * @param result The evaluated boolean result.
 */
- (void)addFeatureFlagWithName:(NSString *)name result:(BOOL)result;

/**
 * Removes a feature flag evaluation from the @c Scope of the Hub.
 * @param name The feature flag name.
 */
- (void)removeFeatureFlagWithName:(NSString *)name;

/// Returns the client if there is a bound client on the Hub.
- (SentryObjCClient *_Nullable)getClient;

/// Returns either the current scope or a new one if it was nil.
@property (nonatomic, readonly, strong) SentryObjCScope *scope;

/// Binds a different client to the hub.
- (void)bindClient:(SentryObjCClient *_Nullable)client;

/**
 * Checks if integration is activated.
 * @param integrationName The name of the integration to check.
 * @return @c YES if the integration is activated.
 */
- (BOOL)hasIntegration:(NSString *)integrationName;

/**
 * Checks if a specific integration class has been installed.
 * @param integrationClass The class of the integration to check.
 * @return @c YES if an instance of @c integrationClass exists.
 */
- (BOOL)isIntegrationInstalled:(Class)integrationClass;

/**
 * Set user to the @c Scope of the Hub.
 * @param user The user to set to the @c Scope.
 */
- (void)setUser:(SentryObjCUser *_Nullable)user;

/**
 * Reports to the ongoing UIViewController transaction that the screen contents are fully loaded
 * and displayed, which will create a new span.
 */
- (void)reportFullyDisplayed;

/**
 * Waits synchronously for the SDK to flush out all queued and cached items for up to the
 * specified timeout in seconds. If there is no internet connection, the function returns
 * immediately. The SDK doesn't dispose the client or the hub.
 * @param timeout The time to wait for the SDK to complete the flush.
 */
- (void)flush:(NSTimeInterval)timeout;

/// Calls flush with @c shutdownTimeInterval.
- (void)close;

@end

NS_ASSUME_NONNULL_END
