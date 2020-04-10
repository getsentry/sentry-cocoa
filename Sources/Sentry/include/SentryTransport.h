#import <Foundation/Foundation.h>

#import "SentryEvent.h"
#import "SentryEnvelope.h"
#import "SentryFileManager.h"

NS_ASSUME_NONNULL_BEGIN

// TODO: align with unified SDK api
/**
 * Sends data to the Sentry server.
 */
NS_SWIFT_NAME(Transport)
@protocol SentryTransport <NSObject>

/**
 * Sends an event to sentry.
 * Triggerd when a event occurs. Thus the first try to upload an event.
 * CompletionHandler will be called if set.
 *
 * Failure to send will most likely keep this event on disk to batch upload with
 * `sendAllStoredEvent` on next app launch.
 *
 * @param event SentryEvent that should be sent
 * @param completionHandler SentryRequestFinished
 */
- (void)sendEvent:(SentryEvent *)event
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler
NS_SWIFT_NAME(send(event:completion:));

- (void) sendEnvelope:(SentryEnvelope *)envelope
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler
NS_SWIFT_NAME(send(envelope:completion:));

/**
 * Sends all events stored on disk. Those events haven't been uploaded
 * successfully at the first attempt (via `sendEvent:withCompletionHandler`)
 * and have been kept on disk to retry.
 *
 * If an event fails to be sent (again), it will be discarded regardless.
 *
 * Triggered when SDK initializes (which is most likely on app startup).
 *
 * Triggers NSNotification @"Sentry/allStoredEventsSent" when done.
 */
- (void)sendAllStoredEvents;

@end

NS_ASSUME_NONNULL_END
