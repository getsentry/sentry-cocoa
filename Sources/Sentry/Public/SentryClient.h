#import <Foundation/Foundation.h>

#import "SentryDefines.h"

@class SentryOptions, SentrySession, SentryEvent, SentryScope, SentryFileManager, SentryId;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Client)
@interface SentryClient : NSObject
SENTRY_NO_INIT

@property (nonatomic, strong) SentryOptions *options;

/**
 * Initializes a SentryClient. Pass in an dictionary of options.
 *
 * @param options Options dictionary
 * @return SentryClient
 */
- (_Nullable instancetype)initWithOptions:(SentryOptions *)options;

/**
 * Captures an SentryEvent.
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureEvent:(SentryEvent *)event
                 NS_SWIFT_NAME(capture(event:));

/**
 * Captures an SentryEvent.
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(event:scope:));

/**
 * Captures a NSError
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureError:(NSError *)error NS_SWIFT_NAME(capture(error:));

/**
 * Captures a NSError
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureError:(NSError *)error
                 withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(error:scope:));

/**
 * Captures a NSException
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureException:(NSException *)exception NS_SWIFT_NAME(capture(exception:));

/**
 * Captures a NSException
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureException:(NSException *)exception
                     withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(exception:scope:));

/**
 * Captures a Message
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureMessage:(NSString *)message NS_SWIFT_NAME(capture(message:));

/**
 * Captures a Message
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(message:scope:));

- (void)captureSession:(SentrySession *)session NS_SWIFT_NAME(capture(session:));

- (SentryFileManager *)fileManager;

@end

NS_ASSUME_NONNULL_END
