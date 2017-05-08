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
#import <Sentry/SentryQueueableRequestManager.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryNSURLRequest.h>

#else
#import "SentryClient.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryQueueableRequestManager.h"
#import "SentryEvent.h"
#import "SentryNSURLRequest.h"
#endif

NS_ASSUME_NONNULL_BEGIN

static SentryClient *sharedClient = nil;
static SentryLogLevel logLevel = kSentryLogLevelError;
static NSDictionary<NSString *, id> *infoDictionary = nil;

@interface SentryClient ()

@property(nonatomic, strong) SentryDsn *dsn;
@property(nonatomic, strong) id <SentryRequestManager> requestManager;

@end

@implementation SentryClient

@dynamic logLevel;

#pragma mark Initializer

- (instancetype)initWithDsn:(NSString *)dsn
           didFailWithError:(NSError *_Nullable *_Nullable)error {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    return [self initWithDsn:dsn
              requestManager:[[SentryQueueableRequestManager alloc] initWithSession:session]
            didFailWithError:error];
}

- (instancetype)initWithDsn:(NSString *)dsn
             requestManager:(id <SentryRequestManager>)requestManager
           didFailWithError:(NSError *_Nullable *_Nullable)error {
    self = [super init];
    if (self) {
        self.dsn = [[SentryDsn alloc] initWithString:dsn didFailWithError:error];
        if (nil != error && nil != *error) {
            [SentryLog logWithMessage:(*error).localizedDescription andLevel:kSentryLogLevelError];
            return nil;
        }
        self.requestManager = requestManager;
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Started -- Version: %@", self.class.versionString] andLevel:kSentryLogLevelDebug];
    }
    return self;
}

#pragma mark Static Getter/Setter

+ (_Nullable instancetype)sharedClient {
    return sharedClient;
}

+ (void)setSharedClient:(SentryClient *)client {
    sharedClient = client;
}


+ (NSString *)versionString {
    if (nil == infoDictionary) {
        infoDictionary = [[NSBundle bundleForClass:[SentryClient class]] infoDictionary];
    }
    return infoDictionary[@"CFBundleShortVersionString"];
}

+ (void)setLogLevel:(SentryLogLevel)level {
    logLevel = level;
}

+ (SentryLogLevel)logLevel {
    return logLevel;
}

#pragma mark Event

- (void)sendEvent:(SentryEvent *)event withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.dsn andEvent:event];
    __block SentryClient* _self = self;
    [self.requestManager addRequest:request completionHandler:^(NSError *_Nullable error) {
        if (completionHandler) {
            completionHandler(error);
        }
        if (nil == error) {
            _self.lastEvent = event;
        }
    }];
}

#if __has_include(<KSCrash/KSCrash.h>)
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error {
    // TODO add kscrash version
    [SentryLog logWithMessage:[NSString stringWithFormat:@"KSCrashHandler started"] andLevel:kSentryLogLevelDebug];
    [[KSCrash sharedInstance] install];
    return YES;
}
#else

- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error {
    NSString *message = @"KSCrashHandler not started - Make sure you added KSCrash as a dependency";
    [SentryLog logWithMessage:message andLevel:kSentryLogLevelError];
    if (nil != error) {
        *error = NSErrorFromSentryError(kSentryErrorKSCrashNotInstalledError, message);
    }
    return NO;
}

#endif

@end

NS_ASSUME_NONNULL_END
