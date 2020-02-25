//
//  SentryScope.m
//  Sentry
//
//  Created by Klemens Mantzos on 15.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryScope.h>
#import <Sentry/SentryScope+Private.h>
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
#import <Sentry/SentryGlobalEventProcessor.h>
#else
#import "SentryScope.h"
#import "SentryScope+Private.h"
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

@synthesize extra = _extra;
@synthesize tags = _tags;
@synthesize user = _user;
@synthesize context = _context;
@synthesize breadcrumbs = _breadcrumbs;

#pragma mark Initializer

- (instancetype)init {
    if (self = [super init]) {
        self.listeners = [NSMutableArray new];
        [self clear];
    }
    return self;
}

#pragma mark Global properties

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Add breadcrumb: %@", crumb] andLevel:kSentryLogLevelDebug];
    [_breadcrumbs addObject:crumb];
    [self notifyListeners];
}

- (void)clear {
    _breadcrumbs = [NSMutableArray new];
    _user = nil;
    _tags = [NSMutableDictionary new];
    _extra = [NSMutableDictionary new];
    _context = [NSMutableDictionary new];
    [self notifyListeners];
}

- (void)clearBreadcrumbs {
    [_breadcrumbs removeAllObjects];
    [self notifyListeners];
}

- (void)setContextValue:(NSDictionary<NSString *, id>*)value forKey:(NSString *)key {
    [_context setValue:value forKey:key];
    [self notifyListeners];
}

- (void)setExtraValue:(id)value forKey:(NSString *)key {
    [_extra setValue:value forKey:key];
    [self notifyListeners];
}

- (void)setExtra:(NSDictionary<NSString *,id> *_Nullable)extra {
    if (extra == nil) {
        _extra = [NSMutableDictionary new];
    } else {
        _extra = extra.mutableCopy;
    }
    [self notifyListeners];
}

- (void)setTagValue:(id)value forKey:(NSString *)key {
    [_tags setValue:value forKey:key];
    [self notifyListeners];
}

- (void)setTags:(NSDictionary<NSString *,NSString *> *_Nullable)tags {
    if (tags == nil) {
        _tags = [NSMutableDictionary new];
    } else {
        _tags = tags.mutableCopy;
    }
    [self notifyListeners];
}

- (void)setUser:(SentryUser *_Nullable)user {
    _user = user;
    [self notifyListeners];
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

- (SentryEvent * __nullable)applyToEvent:(SentryEvent *)event maxBreadcrumb:(NSUInteger)maxBreadcrumbs {
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

    if (nil != self.breadcrumbs) {
        if (nil == event.breadcrumbs) {
            event.breadcrumbs = [self.breadcrumbs subarrayWithRange:NSMakeRange(0, MIN(maxBreadcrumbs, [self.breadcrumbs count]))];
        }
    }
    
    if (nil != self.context) {
        if (nil == event.context) {
            event.context = self.context;
        } else {
            NSMutableDictionary *newContext = [NSMutableDictionary new];
            [newContext addEntriesFromDictionary:self.context];
            [newContext addEntriesFromDictionary:event.context];
            event.context = newContext;
        }
    }

    event = [self callEventProcessors:event];

    if (nil == event) {
        return nil;
    }

    return event;
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
