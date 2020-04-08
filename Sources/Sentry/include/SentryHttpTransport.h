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
#import <Sentry/SentryEnvelope.h>
#import <Sentry/SentryTransport.h>

#else
#import "SentryDefines.h"
#import "SentryScope.h"
#import "SentryEvent.h"
#import "SentryEnvelope.h"
#import "SentryTransport.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryHttpTransport : NSObject <SentryTransport>
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

@end

NS_ASSUME_NONNULL_END
