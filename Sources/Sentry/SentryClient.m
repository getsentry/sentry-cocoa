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
#import <Sentry/SentryKSCrashInstallation.h>

#else
#import "SentryClient.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryQueueableRequestManager.h"
#import "SentryEvent.h"
#import "SentryNSURLRequest.h"
#import "SentryKSCrashInstallation.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryClientVersionString = @"3.0.0";

static SentryClient *sharedClient = nil;
static SentryLogLevel logLevel = kSentryLogLevelError;

static SentryKSCrashInstallation *installation = nil;

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

- (void)crash {
    if ([self.class isTesting]) {
        [SentryLog logWithMessage:@"Would have crashed - but since we run in DEBUG we do nothing." andLevel:kSentryLogLevelDebug];
    } else {
        int* p = 0;
        *p = 0;
    }
}

+ (BOOL)isTesting {
    NSDictionary* environment = [[NSProcessInfo processInfo] environment];
    return [environment objectForKey:@"TESTING"] != nil;
}

#pragma mark Static Getter/Setter

+ (_Nullable instancetype)sharedClient {
    return sharedClient;
}

+ (void)setSharedClient:(SentryClient *)client {
    sharedClient = client;
}

+ (NSString *)versionString {
    return SentryClientVersionString;
}

+ (void)setLogLevel:(SentryLogLevel)level {
    NSParameterAssert(level);
    logLevel = level;
}

+ (SentryLogLevel)logLevel {
    return logLevel;
}

#pragma mark Event

- (void)sendEvent:(SentryEvent *)event withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    NSParameterAssert(event);
    NSError *requestError = nil;
    SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.dsn andEvent:event didFailWithError:&requestError];
    if (nil != requestError) {
        [SentryLog logWithMessage:requestError.localizedDescription andLevel:kSentryLogLevelError];
        completionHandler(requestError);
        return;
    }
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
    [SentryLog logWithMessage:[NSString stringWithFormat:@"KSCrashHandler started"] andLevel:kSentryLogLevelDebug];
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        installation = [[SentryKSCrashInstallation alloc] init];
        [installation install];
        [installation sendAllReports];
    });
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
