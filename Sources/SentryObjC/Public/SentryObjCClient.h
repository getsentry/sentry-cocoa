#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCOptions;
@class SentryObjCEvent;
@class SentryObjCScope;
@class SentryObjCId;
@class SentryObjCFeedback;

NS_ASSUME_NONNULL_BEGIN

/**
 * The Sentry client is responsible for capturing events and sending them to Sentry.
 */
@interface SentryObjCClient : NSObject
SENTRY_NO_INIT

/**
 * Initializes a @c SentryObjCClient. Pass in an options object.
 * @param options The options to configure the client.
 * @return An initialized @c SentryObjCClient or @c nil if an error occurred.
 */
- (nullable instancetype)initWithOptions:(SentryObjCOptions *)options;

/// Indicates whether the client is enabled and will send events to Sentry.
@property (nonatomic, readonly) BOOL isEnabled;

/// The options used to configure this client.
@property (nonatomic, strong) SentryObjCOptions *options;

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
 * @param scope The current scope from which to gather contextual information.
 */
- (void)captureFeedback:(SentryObjCFeedback *)feedback
              withScope:(SentryObjCScope *)scope NS_SWIFT_NAME(capture(feedback:scope:));

/**
 * Waits synchronously for the SDK to flush out all queued and cached items for up to the
 * specified timeout in seconds. If there is no internet connection, the function returns
 * immediately. The SDK doesn't dispose the client or the hub.
 * @param timeout The time to wait for the SDK to complete the flush.
 */
- (void)flush:(NSTimeInterval)timeout;

/// Disables the client and calls flush with the configured shutdown time interval.
- (void)close;

@end

NS_ASSUME_NONNULL_END
