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

/**
 * Set global user -> thus will be sent with every event
 */
@property(nonatomic, strong) SentryUser *_Nullable user;

/**
 * Set global tags -> these will be sent with every event
 */
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable tags;

/**
 * Set global extra -> these will be sent with every event
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable extra;

/**
 * used to add values in event context.
 */
@property(nonatomic, strong) NSDictionary<NSString *, NSDictionary<NSString *, id>*> *_Nullable context;

/**
 * Contains the breadcrumbs which will be sent with the event
 */
@property(nonatomic, strong) NSMutableArray<SentryBreadcrumb *> *breadcrumbs;

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

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Add breadcrumb: %@", crumb] andLevel:kSentryLogLevelDebug];
    [self.breadcrumbs addObject:crumb];
}

- (void)clearBreadcrumbs {
    [self.breadcrumbs removeAllObjects];
}

- (NSDictionary<NSString *, id> *)serializeBreadcrumbs {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    NSMutableArray *crumbs = [NSMutableArray new];
    
    for (SentryBreadcrumb *crumb in self.breadcrumbs) {
        [crumbs addObject:[crumb serialize]];
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
    [serializedData setValue:self.context forKey:@"context"];
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

    event.context.customContext = self.context;

    event = [self callEventProcessors:event];

    if (nil == event) {
        return nil;
    }

    return event;
}

- (void)setContextValue:(NSDictionary<NSString *, id>*)value forKey:(NSString *)key {
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
