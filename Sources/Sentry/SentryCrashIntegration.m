//
//  SentryCrashIntegration.m
//  Sentry
//
//  Created by Klemens Mantzos on 04.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryCrashIntegration.h>
#import <Sentry/SentryInstallation.h>
#import <Sentry/SentryOptions.h>
#import <Sentry/SentryLog.h>
#else
#import "SentryCrashIntegration.h"
#import "SentryInstallation.h"
#import "SentryOptions.h"
#import "SentryLog.h"
#endif

static SentryInstallation *installation = nil;

@interface SentryCrashIntegration ()

@property(nonatomic, weak) SentryOptions *options;

@end

@implementation SentryCrashIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options {
    self.options = options;
    NSError *error = nil;
    return [self startCrashHandlerWithError:&error];
}

- (nonnull NSString *)name {
    return NSStringFromClass([self class]);
}

- (nonnull NSString *)version {
    return @"1.0";
}

- (nonnull NSString *)identifier {
    return [NSString stringWithFormat:@"%@-%@", [self name], [self version]];
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

// TODO(fetzig) this was in client, used for testing only, not sure if we can still use this (for testing). maybe move it to hub or static-sdk?
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

// TODO(fetzig) this was in client, used for testing only, not sure if we can still use this (for testing). maybe move it to hub or static-sdk?
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

- (BOOL)crashedLastLaunch {
    return SentryCrash.sharedInstance.crashedLastLaunch;
}

@end
