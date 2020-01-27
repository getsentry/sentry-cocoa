//
//  SentryScope.m
//  Sentry
//
//  Created by Klemens Mantzos on 15.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryScope.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryDsn.h>
#import <Sentry/SentryError.h>
#import <Sentry/SentryUser.h>
#import <Sentry/SentryQueueableRequestManager.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryNSURLRequest.h>
#import <Sentry/SentryInstallation.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryCrash.h>
#import <Sentry/SentryOptions.h>
#import <Sentry/SentryContext.h>
#import <Sentry/SentryGlobalEventProcessor.h>
#else
#import "SentryScope.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryUser.h"
#import "SentryQueueableRequestManager.h"
#import "SentryEvent.h"
#import "SentryNSURLRequest.h"
#import "SentryInstallation.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryBreadcrumb.h"
#import "SentryCrash.h"
#import "SentryOptions.h"
#import "SentryContext.h"
#import "SentryGlobalEventProcessor.h"
#endif

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryScope ()

@end

@implementation SentryScope

#pragma mark Initializer

- (instancetype)init {
    if (self = [super init]) {
        // nothing to do here
    }
    return self;
}

#pragma mark Global properties

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb withMaxBreadcrumbs:(NSUInteger)maxBreadcrumbs {
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Add breadcrumb: %@", crumb] andLevel:kSentryLogLevelDebug];
    [self.breadcrumbs addObject:crumb];
    if ([self.breadcrumbs count] > maxBreadcrumbs) {
        [self.breadcrumbs removeObjectAtIndex:0];
    }
}

- (void)clearBreadcrumbs {
    [self.breadcrumbs removeAllObjects];
}

- (NSDictionary<NSString *, id> *)serializeBreadcrumbs {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    NSMutableArray *crumbs = [NSMutableArray new];
    for (SentryBreadcrumb *crumb in self.breadcrumbs) {
        id serializedCrumb = [NSJSONSerialization JSONObjectWithData:[crumb serialize][@"data"] options:0 error:nil];
        if (serializedCrumb != nil) {
            [crumbs addObject:serializedCrumb];
        }
    }
    if (crumbs.count > 0) {
        [serializedData setValue:crumbs forKey:@"breadcrumbs"];
    }

    return serializedData;
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = [[self serializeBreadcrumbs] mutableCopy];
    [serializedData setValue:self.tags forKey:@"tags"];
    [serializedData setValue:self.extra forKey:@"extra"];
    [serializedData setValue:[self.user serialize] forKey:@"user"];
    return serializedData;
}

- (SentryEvent * __nullable)applyToEvent:(SentryEvent *)event {
    if (nil != self.tags) {
        if (nil == event.tags) {
            event.tags = self.tags;
        } else {
            NSMutableDictionary *newTags = [NSMutableDictionary new];
            [newTags addEntriesFromDictionary:self.tags];
            [newTags addEntriesFromDictionary:event.tags];
            event.tags = newTags;
        }
    }

    if (nil != self.extra) {
        if (nil == event.extra) {
            event.extra = self.extra;
        } else {
            NSMutableDictionary *newExtra = [NSMutableDictionary new];
            [newExtra addEntriesFromDictionary:self.extra];
            [newExtra addEntriesFromDictionary:event.extra];
            event.extra = newExtra;
        }
    }

    if (nil != self.user && nil == event.user) {
        event.user = self.user;
    }

    if (nil == event.breadcrumbsSerialized) {
        event.breadcrumbsSerialized = [self serializeBreadcrumbs];
    }

    if (nil == event.infoDict) {
        event.infoDict = [[NSBundle mainBundle] infoDictionary];
    }

    event.context.customContext = self.context;

    event = [self callEventProcessors:event];

    if (nil == event) {
        return nil;
    }

    return event;
}

- (void)setContextValue:(id)value forKey:(NSString *)key {
    [self.context setValue:value forKey:key];
}

- (SentryEvent *)callEventProcessors:(SentryEvent *)event {
    SentryEvent *newEvent = event;

    for (SentryEventProcessor processor in SentryGlobalEventProcessor.shared.processors) {

        newEvent = processor(newEvent);

        if (nil == newEvent) {
            [SentryLog logWithMessage:@"SentryScope callEventProcessors: an event processor decided to remove this event." andLevel:kSentryLogLevelDebug];
            break;
        }
    }
    return newEvent;
}

@end

NS_ASSUME_NONNULL_END
