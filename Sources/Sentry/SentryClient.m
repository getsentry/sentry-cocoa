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

@implementation SentryClient

@synthesize options = _options;
@dynamic logLevel;

#pragma mark Initializer

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                         didFailWithError:(NSError *_Nullable *_Nullable)error {


    if (self = [super init]) {
//            //[self restoreContextBeforeCrash];
//            [self setupQueueing];
    //        _extra = [NSDictionary new];
    //        _tags = [NSDictionary new];

            self.options = options;

    //        self.dsn = sentryOptions.dsn;
    //        self.environment = sentryOptions.environment;
    //        self.releaseName = sentryOptions.releaseName;
    //        self.dist = sentryOptions.dist;

//            self.requestManager = requestManager;
//            if (logLevel > 1) { // If loglevel is set > None
//                NSLog(@"Sentry Started -- Version: %@", self.class.versionString);
//            }


            // We want to send all stored events on start up
            if ([self.options.enabled boolValue]) {
                [SentryTransport.shared sendAllStoredEvents];
            }
        }
        return self;
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

- (void)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope {
    [SentryTransport.shared sendEvent:event scope:scope withCompletionHandler:nil];
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

@end

NS_ASSUME_NONNULL_END
