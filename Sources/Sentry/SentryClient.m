//
//  SentryClient.m
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryClient.h>
#import <Sentry/SentryClient+Internal.h>
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
#import "SentryClient+Internal.h"
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

// TODO(fetzig): dry: get version string from Sentry.xconfig instead.
NSString *const SentryClientVersionString = @"5.0.0";
NSString *const SentryClientSdkName = @"sentry-cocoa";

static SentryLogLevel logLevel = kSentryLogLevelError;

static SentryInstallation *installation = nil;

@interface SentryClient ()

@property(nonatomic, strong) SentryTransport* transport;

@end

@implementation SentryClient

@synthesize sampleRate = _sampleRate;
@synthesize options = _options;
@synthesize transport = _transport;
@dynamic logLevel;

#pragma mark Initializer

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                         didFailWithError:(NSError *_Nullable *_Nullable)error {


    if (self = [super init]) {
//            //[self restoreContextBeforeCrash];
//            [self setupQueueing];
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
    return [self initWithOptions:options didFailWithError:error];
}

- (void)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope {
    if (NO == [self checkSampleRate]) {
        NSString *message = @"SentryClient shouldSendEvent returned NO so we will not send the event";
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


- (void)appendStacktraceToEvent:(SentryEvent *)event {
    if (nil != self._snapshotThreads && nil != self._debugMeta) {
        event.threads = self._snapshotThreads;
        event.debugMeta = self._debugMeta;
    }
}

#pragma mark Global properties

#pragma mark SentryCrash

- (BOOL)crashedLastLaunch {
    return SentryCrash.sharedInstance.crashedLastLaunch;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error {
    [SentryLog logWithMessage:@"SentryCrashHandler started" andLevel:kSentryLogLevelDebug];
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        installation = [[SentryInstallation alloc] init];
        [installation install];
        [installation sendAllReports];
    });
    return YES;
}
#pragma GCC diagnostic pop

- (void)reportUserException:(NSString *)name
                     reason:(NSString *)reason
                   language:(NSString *)language
                 lineOfCode:(NSString *)lineOfCode
                 stackTrace:(NSArray *)stackTrace
              logAllThreads:(BOOL)logAllThreads
           terminateProgram:(BOOL)terminateProgram {
    if (nil == installation) {
        [SentryLog logWithMessage:@"SentryCrash has not been initialized, call startCrashHandlerWithError" andLevel:kSentryLogLevelError];
        return;
    }
    [SentryCrash.sharedInstance reportUserException:name
                                         reason:reason
                                       language:language
                                     lineOfCode:lineOfCode
                                     stackTrace:stackTrace
                                  logAllThreads:logAllThreads
                               terminateProgram:terminateProgram];
    [installation sendAllReports];
}

- (void)snapshotStacktrace:(void (^)(void))snapshotCompleted {
    if (nil == installation) {
        [SentryLog logWithMessage:@"SentryCrash has not been initialized, call startCrashHandlerWithError" andLevel:kSentryLogLevelError];
        return;
    }
    [SentryCrash.sharedInstance reportUserException:@"SENTRY_SNAPSHOT"
                                         reason:@"SENTRY_SNAPSHOT"
                                       language:@""
                                     lineOfCode:@""
                                     stackTrace:[[NSArray alloc] init]
                                  logAllThreads:NO
                               terminateProgram:NO];
    [installation sendAllReportsWithCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
        snapshotCompleted();
    }];
}

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

- (void)setSampleRate:(float)sampleRate {
    if (sampleRate < 0 || sampleRate > 1) {
        [SentryLog logWithMessage:@"sampleRate must be between 0.0 and 1.0" andLevel:kSentryLogLevelError];
        return;
    }
    _sampleRate = sampleRate;
}

/**
 checks if event should be sent according to sampleRate
 returns BOOL
 */
- (BOOL)checkSampleRate {
    if (self.sampleRate < 0 || self.sampleRate > 1) {
        [SentryLog logWithMessage:@"sampleRate must be between 0.0 and 1.0, checkSampleRate is skipping check and returns YES" andLevel:kSentryLogLevelError];
        return YES;
    }
    return (self.sampleRate >= ((double)arc4random() / 0x100000000));
}

@end

NS_ASSUME_NONNULL_END
