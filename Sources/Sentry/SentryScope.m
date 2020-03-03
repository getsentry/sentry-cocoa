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
#import <Sentry/SentryUser.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryGlobalEventProcessor.h>
#else
#import "SentryScope.h"
#import "SentryScope+Private.h"
#import "SentryLog.h"
#import "SentryUser.h"
#import "SentryEvent.h"
#import "SentryGlobalEventProcessor.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryScope ()

/**
 * Set global user -> thus will be sent with every event
 */
@property(atomic, strong) SentryUser *_Nullable userObject;

/**
 * Set global tags -> these will be sent with every event
 */
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *_Nullable tagDictionary;

/**
 * Set global extra -> these will be sent with every event
 */
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *_Nullable extraDictionary;

/**
 * used to add values in event context.
 */
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary<NSString *, id>*> *_Nullable contextDictionary;

/**
 * Contains the breadcrumbs which will be sent with the event
 */
@property(nonatomic, strong) NSMutableArray<SentryBreadcrumb *> *breadcrumbArray;

/**
 * The release version name of the application.
 */
@property(atomic, copy) NSString *_Nullable releaseString;

/**
 * This distribution of the application.
 */
@property(atomic, copy) NSString *_Nullable distString;

/**
 * The environment used in this scope.
 */
@property(atomic, copy) NSString *_Nullable environmentString;

/**
 * Set the fingerprint of an event to determine the grouping
 */
@property(atomic, strong) NSArray<NSString *> *_Nullable fingerprintArray;

/**
 * SentryLevel of the event
 */
@property(atomic) enum SentryLevel levelEnum;

@end

@implementation SentryScope

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
        self.extraDictionary = scope.extraDictionary.mutableCopy;
        self.tagDictionary = scope.tagDictionary.mutableCopy;
        SentryUser *scopeUser = scope.userObject;
        SentryUser *user = nil;
        if (nil != scopeUser) {
            user = [[SentryUser alloc] init];
            user.userId = scopeUser.userId;
            user.data = scopeUser.data.mutableCopy;
            user.username = scopeUser.username;
            user.email = scopeUser.email;
        }
        self.userObject = user;
        self.contextDictionary = scope.contextDictionary.mutableCopy;
        self.breadcrumbArray = scope.breadcrumbArray.mutableCopy;
        self.releaseString = scope.releaseString;
        self.distString = scope.distString;
        self.environmentString = scope.environmentString;
        self.levelEnum = scope.levelEnum;
        self.fingerprintArray = scope.fingerprintArray.mutableCopy;
    }
    return self;
}

#pragma mark Global properties

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Add breadcrumb: %@", crumb] andLevel:kSentryLogLevelDebug];
    @synchronized (self) {
        [self.breadcrumbArray addObject:crumb];
    }
    [self notifyListeners];
}

- (void)clear {
    @synchronized (self) {
        self.breadcrumbArray = [NSMutableArray new];
        self.userObject = nil;
        self.tagDictionary = [NSMutableDictionary new];
        self.extraDictionary = [NSMutableDictionary new];
        self.contextDictionary = [NSMutableDictionary new];
        self.releaseString = nil;
        self.distString = nil;
        self.environmentString = nil;
        self.levelEnum = kSentryLevelNone;
        self.fingerprintArray = [NSMutableArray new];
    }
    [self notifyListeners];
}

- (void)clearBreadcrumbs {
    @synchronized (self) {
        [self.breadcrumbArray removeAllObjects];
    }
    [self notifyListeners];
}

- (void)setContextValue:(NSDictionary<NSString *, id>*)value forKey:(NSString *)key {
    @synchronized (self) {
        [self.contextDictionary setValue:value forKey:key];
    }
    [self notifyListeners];
}

- (void)setExtraValue:(id)value forKey:(NSString *)key {
    @synchronized (self) {
        [self.extraDictionary setValue:value forKey:key];
    }
    [self notifyListeners];
}

- (void)setExtras:(NSDictionary<NSString *,id> *_Nullable)extras {
    if (extras == nil) {
        return;
    }
    @synchronized (self) {
        [self.extraDictionary addEntriesFromDictionary:extras];
    }
    [self notifyListeners];
}

- (void)setTagValue:(id)value forKey:(NSString *)key {
    @synchronized (self) {
        [self.tagDictionary setValue:value forKey:key];
    }
    [self notifyListeners];
}

- (void)setTags:(NSMutableDictionary<NSString *,NSString *> *_Nullable)tags {
    if (tags == nil) {
        return;
    }
    @synchronized (self) {
        [self.tagDictionary addEntriesFromDictionary:tags];
    }
    [self notifyListeners];
}

- (void)setUser:(SentryUser *_Nullable)user {
    self.userObject = user;
    [self notifyListeners];
}

- (void)setRelease:(NSString *_Nullable)releaseName {
    self.releaseString = releaseName;
    [self notifyListeners];
}

- (void)setDist:(NSString *_Nullable)dist {
    self.distString = dist;
    [self notifyListeners];
}

- (void)setEnvironment:(NSString *_Nullable)environment {
    self.environmentString = environment;
    [self notifyListeners];
}

- (void)setFingerprint:(NSArray<NSString *> *_Nullable)fingerprint {
    @synchronized (self) {
        if (fingerprint == nil) {
            self.fingerprintArray = [NSMutableArray new];
        } else {
            self.fingerprintArray = fingerprint.mutableCopy;
        }
        self.fingerprintArray = fingerprint;
    }
    [self notifyListeners];
}

- (void)setLevel:(enum SentryLevel)level {
    self.levelEnum = level;
    [self notifyListeners];
}

- (NSDictionary<NSString *, id> *)serializeBreadcrumbs {
    NSMutableArray *crumbs = [NSMutableArray new];
    
    for (SentryBreadcrumb *crumb in self.breadcrumbArray) {
        [crumbs addObject:[crumb serialize]];
    }
 
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    if (crumbs.count > 0) {
        [serializedData setValue:crumbs forKey:@"breadcrumbs"];
    }
    
    return serializedData;
}

- (NSDictionary<NSString *, id> *)serialize {
    @synchronized (self) {
        NSMutableDictionary *serializedData = [[self serializeBreadcrumbs] mutableCopy];
        [serializedData setValue:self.tagDictionary forKey:@"tags"];
        [serializedData setValue:self.extraDictionary forKey:@"extra"];
        [serializedData setValue:self.contextDictionary forKey:@"context"];
        [serializedData setValue:[self.userObject serialize] forKey:@"user"];
        [serializedData setValue:self.releaseString forKey:@"release"];
        [serializedData setValue:self.distString forKey:@"dist"];
        [serializedData setValue:self.environmentString forKey:@"environment"];
        [serializedData setValue:self.fingerprintArray forKey:@"fingerprint"];
        if (self.levelEnum != kSentryLevelNone) {
            [serializedData setValue:SentryLevelNames[self.levelEnum] forKey:@"level"];
        }
        return serializedData;
    }
}

- (SentryEvent * __nullable)applyToEvent:(SentryEvent *)event maxBreadcrumb:(NSUInteger)maxBreadcrumbs {
    @synchronized (self) {
        if (nil != self.tagDictionary) {
            if (nil == event.tags) {
                event.tags = self.tagDictionary.copy;
            } else {
                NSMutableDictionary *newTags = [NSMutableDictionary new];
                [newTags addEntriesFromDictionary:self.tagDictionary];
                [newTags addEntriesFromDictionary:event.tags];
                event.tags = newTags;
            }
        }

        if (nil != self.extraDictionary) {
            if (nil == event.extra) {
                event.extra = self.extraDictionary.copy;
            } else {
                NSMutableDictionary *newExtra = [NSMutableDictionary new];
                [newExtra addEntriesFromDictionary:self.extraDictionary];
                [newExtra addEntriesFromDictionary:event.extra];
                event.extra = newExtra;
            }
        }

        if (nil != self.userObject) {
            event.user = self.userObject.copy;
        }
        
        NSString *releaseName = [self releaseString];
        if (nil != releaseName && nil == event.releaseName) {
            // release can also be set via options but scope takes precedence.
            event.releaseName = releaseName;
        }
        
        NSString *dist = self.distString;
        if (nil != dist && nil == event.dist) {
            // dist can also be set via options but scope takes precedence.
            event.dist = dist;
        }
        
        NSString *environment = self.environmentString;
        if (nil != environment && nil == event.environment) {
            // environment can also be set via options but scope takes precedence.
            event.environment = environment;
        }

        NSArray *fingerprint = self.fingerprintArray;
        if (fingerprint.count > 0 && nil == event.fingerprint) {
            event.fingerprint = fingerprint.mutableCopy;
        }
        
        if (self.levelEnum != kSentryLevelNone) {
            // We always want to set the level from the scope since this has benn set on purpose
            event.level = self.levelEnum;
        }
        
        if (nil != self.breadcrumbArray) {
            if (nil == event.breadcrumbs) {
                event.breadcrumbs = [self.breadcrumbArray subarrayWithRange:NSMakeRange(0, MIN(maxBreadcrumbs, [self.breadcrumbArray count]))];
            }
        }
        
        if (nil != self.contextDictionary) {
            if (nil == event.context) {
                event.context = self.contextDictionary;
            } else {
                NSMutableDictionary *newContext = [NSMutableDictionary new];
                [newContext addEntriesFromDictionary:self.contextDictionary];
                [newContext addEntriesFromDictionary:event.context];
                event.context = newContext;
            }
        }

        return event;
    }
}

@end

NS_ASSUME_NONNULL_END
