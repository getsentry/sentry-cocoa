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
 * This block can be used to modify the request before its put on the request queue.
 * Can be used e.g. to set additional http headers before sending
 */
@property(nonatomic, copy) SentryBeforeSendRequest _Nullable beforeSendRequest;

/**
 * This block can be used to prevent the event from being deleted after a failed send attempt.
 * Default is it will only be stored once after you hit a rate limit or there is no internet connect/cannot connect.
 * Also note that if an event fails to be sent again after it was queued, it will be discarded regardless.
 * @return BOOL YES = store and try again later, NO = delete
 */
@property(nonatomic, copy) SentryShouldQueueEvent _Nullable shouldQueueEvent;

/**
 * Contains the last successfully sent event
 */
@property(nonatomic, strong) SentryEvent *_Nullable lastEvent;

/**
 * Increase the max number of events we store offline.
 * Be careful with this setting since too high numbers may cause your quota to exceed.
 */
@property(nonatomic, assign) NSUInteger maxEvents;

/**
 * Increase the max number of breadcrumbs we store offline.
 */
@property(nonatomic, assign) NSUInteger maxBreadcrumbs;

- (id)initWithOptions:(SentryOptions *)options;

- (void)sendAllStoredEvents;

/**
 * Sends and event to sentry. Internally calls @selector(sendEvent:useClientProperties:withCompletionHandler:) with
 * useClientProperties: YES. CompletionHandler will be called if set.
 * @param event SentryEvent that should be sent
 * @param completionHandler SentryRequestFinished
 */
- (void)    sendEvent:(SentryEvent *)event
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler
NS_SWIFT_NAME(send(event:completion:));

/**
 * This function stores an event to disk. It will be sent with the next batch.
 * This function is mainly used for react native.
 * @param event SentryEvent that should be sent
 */
- (void)storeEvent:(SentryEvent *)event;



@end

NS_ASSUME_NONNULL_END
