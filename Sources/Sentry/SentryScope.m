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

/**
 * The release version name of the application.
 */
@property(nonatomic, copy) NSString *_Nullable releaseName;

/**
 * This distribution of the application.
 */
@property(nonatomic, copy) NSString *_Nullable dist;

/**
 * The environment used in this scope.
 */
@property(nonatomic, copy) NSString *_Nullable environment;

/**
 * Set the fingerprint of an event to determine the grouping
 */
@property(nonatomic, strong) NSArray<NSString *> *_Nullable fingerprint;

/**
 * SentrySeverity of the event
 */
@property(nonatomic) enum SentrySeverity level;

@end

@implementation SentryScope

@synthesize extra = _extra;
@synthesize tags = _tags;
@synthesize user = _user;
@synthesize context = _context;
@synthesize breadcrumbs = _breadcrumbs;
@synthesize releaseName = _releaseName;
@synthesize dist = _dist;
@synthesize environment = _environment;
@synthesize fingerprint = _fingerprint;
@synthesize level = _level;

#pragma mark Initializer

- (instancetype)init {
    if (self = [super init]) {
        self.listeners = [NSMutableArray new];
        [self clear];
    }
    return self;
}

- (instancetype)initWithScope:(SentryScope *)scope {
    if (self = [super init]) {
        self.listeners = [NSMutableArray new];
        self.extra = scope.extra.mutableCopy;
        self.tags = scope.tags.mutableCopy;
        SentryUser *scopeUser = scope.user;
        SentryUser *user = nil;
        if (nil != scopeUser) {
            user = [[SentryUser alloc] init];
            user.userId = scopeUser.userId;
            user.data = scopeUser.data;
            user.username = scopeUser.username;
            user.email = scopeUser.email;
        }
        self.user = user;
        self.context = scope.context.mutableCopy;
        self.breadcrumbs = scope.breadcrumbs.mutableCopy;
        self.releaseName = scope.releaseName;
        self.dist = scope.dist;
        self.environment = scope.environment;
        self.level = scope.level;
        self.fingerprint = scope.fingerprint;
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
    _releaseName = nil;
    _dist = nil;
    _environment = nil;
    _level = nil;
    _fingerprint = [NSMutableArray new];
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

- (void)setReleaseName:(NSString *_Nullable)releaseName {
    _releaseName = releaseName;
    [self notifyListeners];
}

- (void)setDist:(NSString *_Nullable)dist {
    _dist = dist;
    [self notifyListeners];
}

- (void)setEnvironment:(NSString *_Nullable)environment {
    _environment = environment;
    [self notifyListeners];
}

- (void)setFingerprint:(NSArray<NSString *> *_Nullable)fingerprint {
    if (fingerprint == nil) {
        _fingerprint = [NSMutableArray new];
    } else {
        _fingerprint = fingerprint.mutableCopy;
    }
    _fingerprint = fingerprint;
    [self notifyListeners];
}

- (void)setLevel:(enum SentrySeverity)level {
    _level = level;
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
    [serializedData setValue:self.releaseName forKey:@"release"];
    [serializedData setValue:self.dist forKey:@"dist"];
    [serializedData setValue:self.environment forKey:@"environment"];
    [serializedData setValue:self.fingerprint forKey:@"fingerprint"];
    if (self.level) {
        [serializedData setValue:SentrySeverityNames[self.level] forKey:@"level"];
    }
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

    if (nil != self.user) {
        event.user = self.user;
    }
    
    NSString *releaseName = [self releaseName];
    if (nil != releaseName && nil == event.releaseName) {
        // release can also be set via options but scope takes precedence.
        event.releaseName = releaseName;
    }
    
    NSString *dist = self.dist;
    if (nil != dist && nil == event.dist) {
        // dist can also be set via options but scope takes precedence.
        event.dist = dist;
    }
    
    NSString *environment = self.environment;
    if (nil != environment && nil == event.environment) {
        // environment can also be set via options but scope takes precedence.
        event.environment = environment;
    }

    NSArray *fingerprint = self.fingerprint;
    if (fingerprint.count > 0 && nil == event.fingerprint) {
        event.fingerprint = fingerprint.mutableCopy;
    }
    
    if (self.level) {
        // We always want to set the level from the scope since this has benn set on purpose
        event.level = self.level;
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

    return event;
}

@end

NS_ASSUME_NONNULL_END
