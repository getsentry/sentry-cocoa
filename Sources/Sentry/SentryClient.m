//
//  SentryClient.m
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryClient.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryDsn.h>
#import <Sentry/SentryError.h>
#import <Sentry/SentryUser.h>
#import <Sentry/SentryQueueableRequestManager.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryNSURLRequest.h>
#import <Sentry/SentryInstallation.h>
#import <Sentry/SentryFileManager.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#import <Sentry/SentryCrash.h>
#import <Sentry/SentryOptions.h>
#import <Sentry/SentryScope.h>
#import <Sentry/SentryTransport.h>
#else
#import "SentryClient.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryUser.h"
#import "SentryQueueableRequestManager.h"
#import "SentryEvent.h"
#import "SentryNSURLRequest.h"
#import "SentryInstallation.h"
#import "SentryFileManager.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryCrash.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#import "SentryTransport.h"
#endif

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryClientVersionString = @"4.4.3";
NSString *const SentryClientSdkName = @"sentry-cocoa";

static SentryLogLevel logLevel = kSentryLogLevelError;

@interface SentryClient ()

@property(nonatomic, strong) SentryTransport* transport;

@end

@implementation SentryClient

@synthesize options = _options;
@synthesize transport = _transport;
@dynamic logLevel;

#pragma mark Initializer

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options {
    if (self = [super init]) {
        self.options = options;

        // We want to send all stored events on start up
        if ([self.options.enabled boolValue]) {
            [self.transport sendAllStoredEvents];
        }
    }
    return self;
}

- (SentryTransport *)transport {
    if (_transport == nil) {
        _transport = [[SentryTransport alloc] initWithOptions:self.options];
    }
    return _transport;
}
    
- (_Nullable instancetype)initWithDsn:(NSString *)dsn
                     didFailWithError:(NSError *_Nullable *_Nullable)error {
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"dsn": dsn} didFailWithError:error];
    if (nil != error && nil != *error) {
        [SentryLog logWithMessage:(*error).localizedDescription andLevel:kSentryLogLevelError];
        return nil;
    }
    return [self initWithOptions:options];
}

- (void)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope {
    if (NO == [self.options checkSampleRate]) {
        NSString *message = @"[SentryClient.options checkSampleRate] returned NO so we will not send the event";
        [SentryLog logWithMessage:message andLevel:kSentryLogLevelDebug];
        return;
    }

    SentryEvent *preparedEvent = [self prepareEvent:event withScope:scope];
    if (nil != preparedEvent) {
        [self.transport sendEvent:preparedEvent withCompletionHandler:nil];
    }
}

#pragma mark Static Getter/Setter

+ (NSString *)versionString {
    return SentryClientVersionString;
}

+ (NSString *)sdkName {
    return SentryClientSdkName;
}

+ (void)setLogLevel:(SentryLogLevel)level {
    NSParameterAssert(level);
    logLevel = level;
}

+ (SentryLogLevel)logLevel {
    return logLevel;
}

#pragma mark Event

#pragma mark Global properties

#pragma mark SentryCrash

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *)event
                             withScope:(SentryScope *)scope {
    NSParameterAssert(event);
    [self setSharedPropertiesOnEvent:event scope:scope];

    if (nil != self.options.beforeSend) {
        return self.options.beforeSend(event);
    }
    return event;
}

- (void)setSharedPropertiesOnEvent:(SentryEvent *)event
                             scope:(SentryScope *)scope {
    if (nil != scope.tags) {
        if (nil == event.tags) {
            event.tags = scope.tags;
        } else {
            NSMutableDictionary *newTags = [NSMutableDictionary new];
            [newTags addEntriesFromDictionary:scope.tags];
            [newTags addEntriesFromDictionary:event.tags];
            event.tags = newTags;
        }
    }

    if (nil != scope.extra) {
        if (nil == event.extra) {
            event.extra = scope.extra;
        } else {
            NSMutableDictionary *newExtra = [NSMutableDictionary new];
            [newExtra addEntriesFromDictionary:scope.extra];
            [newExtra addEntriesFromDictionary:event.extra];
            event.extra = newExtra;
        }
    }

    if (nil != scope.user && nil == event.user) {
        event.user = scope.user;
    }

    if (nil == event.breadcrumbsSerialized) {
        event.breadcrumbsSerialized = [scope serializeBreadcrumbs];
    }

    if (nil == event.infoDict) {
        event.infoDict = [[NSBundle mainBundle] infoDictionary];
    }
    NSString * environment = self.options.environment;
    if (nil != environment && nil == event.environment) {
        event.environment = environment;
    }

    NSString * releaseName = self.options.releaseName;
    if (nil != releaseName && nil == event.releaseName) {
        event.releaseName = releaseName;
    }

    NSString * dist = self.options.dist;
    if (nil != dist && nil == event.dist) {
        event.dist = dist;
    }
}

@end

NS_ASSUME_NONNULL_END
