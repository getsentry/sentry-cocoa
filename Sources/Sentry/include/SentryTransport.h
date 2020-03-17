//
//  SentryTransport.h
//  Sentry
//
//  Created by Klemens Mantzos on 27.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryDefines.h>
#import <Sentry/SentryScope.h>
#import <Sentry/SentryEvent.h>

#else
#import "SentryDefines.h"
#import "SentryScope.h"
#import "SentryEvent.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryTransport : NSObject
SENTRY_NO_INIT

/**
 * This is triggered after the first upload attempt of an event. Checks if event
 * should stay on disk to be uploaded when `sendAllStoredEvents` is triggerd.
 *
 * Within `sendAllStoredEvents` this function isn't triggerd.
 *
 * @return BOOL YES = store and try again later, NO = delete
 */
@property(nonatomic, copy) SentryShouldQueueEvent _Nullable shouldQueueEvent;

/**
 * Contains the last successfully sent event
 */
@property(nonatomic, strong) SentryEvent *_Nullable lastEvent;


- (id)initWithOptions:(SentryOptions *)options;

/**
 * Sends and event to sentry.
 * Triggerd when a event occurs. Thus the first try to upload an event.
 * CompletionHandler will be called if set.
 *
 * Failure to send will most likely keep this event on disk to batch upload with
 * `sendAllStoredEvent` on next app launch.
 *
 * @param event SentryEvent that should be sent
 * @param completionHandler SentryRequestFinished
 */
- (void)    sendEvent:(SentryEvent *)event
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
