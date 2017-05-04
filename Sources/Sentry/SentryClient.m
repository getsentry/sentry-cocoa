//
//  SentryClient.m
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<KSCrash/KSCrash.h>)
#import <KSCrash/KSCrash.h>
#endif

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryClient.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryDsn.h>
#import <Sentry/SentryError.h>
#else
#import "SentryClient.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryClientVersionString = @"3.0.0";
NSString *const SentryServerVersionString = @"7";

static SentryClient *sharedClient = nil;
static SentryLogLevel logLevel = kError;

@interface SentryClient ()

@property(nonatomic, retain) SentryDsn *dsn;

@end

@implementation SentryClient

@dynamic logLevel;

- (instancetype)initWithDsn:(NSString *)dsn didFailWithError:(NSError *_Nullable *_Nullable)error {
    self = [super init];
    if (self) {
        self.dsn = [[SentryDsn alloc] initWithString:dsn didFailWithError:error];
        if (*error) {
            [SentryLog logWithMessage:(*error).localizedDescription andLevel:kError];
            return nil;
        }
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Started -- Version: %@", self.class.versionString] andLevel:kDebug];
    }
    return self;
}

+ (void)setLogLevel:(SentryLogLevel)level {
    logLevel = level;
}

+ (SentryLogLevel)logLevel {
    return logLevel;
}

+ (instancetype)sharedClient {
    return sharedClient;
}

+ (void)setSharedClient:(SentryClient *)client {
    sharedClient = client;
}

+ (NSString *)versionString {
    return [NSString stringWithFormat:@"%@ (%@)", SentryClientVersionString, SentryServerVersionString];
}

#if __has_include(<KSCrash/KSCrash.h>)
- (void)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error {
    // TODO add kscrash version
    [SentryLog logWithMessage:[NSString stringWithFormat:@"KSCrashHandler started"] andLevel:kDebug];
    [[KSCrash sharedInstance] install];
}
#else
- (void)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error {
    NSString *message = @"KSCrashHandler not started - Make sure you added KSCrash as a dependency";
    [SentryLog logWithMessage:message andLevel:kError];
    *error = NSErrorFromSentryError(kKSCrashNotInstalledError, message);
}
#endif

@end

NS_ASSUME_NONNULL_END
