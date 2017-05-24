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
#import <Sentry/SentryBreadcrumbStore.h>
#import <Sentry/SentryFileManager.h>

#else
#import "SentryClient.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryQueueableRequestManager.h"
#import "SentryEvent.h"
#import "SentryNSURLRequest.h"
#import "SentryKSCrashInstallation.h"
#import "SentryBreadcrumbStore.h"
#import "SentryFileManager.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryClientVersionString = @"3.0.0";

static SentryClient *sharedClient = nil;
static SentryLogLevel logLevel = kSentryLogLevelError;

static SentryKSCrashInstallation *installation = nil;

@interface SentryClient ()

@property(nonatomic, strong) SentryDsn *dsn;
@property(nonatomic, strong) SentryFileManager *fileManager;
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
        self.requestManager = requestManager;
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Started -- Version: %@", self.class.versionString] andLevel:kSentryLogLevelDebug];
        self.fileManager = [[SentryFileManager alloc] initWithError:error];
        self.breadcrumbs = [[SentryBreadcrumbStore alloc] initWithFileManager:self.fileManager];
        if (nil != error && nil != *error) {
            [SentryLog logWithMessage:(*error).localizedDescription andLevel:kSentryLogLevelError];
            return nil;
        }
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
    [self sendEvent:event useClientProperties:YES withCompletionHandler:completionHandler];
}

- (void)    sendEvent:(SentryEvent *)event
  useClientProperties:(BOOL)useClientProperties
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    NSParameterAssert(event);
    if (useClientProperties) {
        event.breadcrumbsSerialized = self.breadcrumbs.serialized;
    }
    NSError *requestError = nil;
    SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.dsn
                                                                             andEvent:event
                                                                     didFailWithError:&requestError];
    if (nil != requestError) {
        [SentryLog logWithMessage:requestError.localizedDescription andLevel:kSentryLogLevelError];
        completionHandler(requestError);
        return;
    }
    __block SentryClient *_self = self;
    [self sendRequest:request withCompletionHandler:^(NSError *_Nullable error) {
        if (nil == error) {
            _self.lastEvent = event;
        } else {
            [_self.fileManager storeEvent:event];
        }
        if (completionHandler) {
            completionHandler(error);
        }
    }];
}

- (void)  sendRequest:(SentryNSURLRequest *)request
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    [self.requestManager addRequest:request completionHandler:completionHandler];
    // Send all stored events in background if the queue is ready
    if ([self.requestManager isReady]) {
        [self sendAllStoredEvents];
    }
}

- (void)sendAllStoredEvents {
    for (NSDictionary<NSString *, id> *fileDictionary in [self.fileManager getAllStoredEvents]) {
        SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.dsn
                                                                                  andData:fileDictionary[@"data"]
                                                                         didFailWithError:nil];
        [self sendRequest:request withCompletionHandler:^(NSError *_Nullable error) {
            if (nil == error) {
                [self.fileManager removeFileAtPath:fileDictionary[@"path"]];
            }
        }];
    }
}

#if __has_include(<KSCrash/KSCrash.h>)
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error {
    [SentryLog logWithMessage:@"KSCrashHandler started" andLevel:kSentryLogLevelDebug];
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        installation = [[SentryKSCrashInstallation alloc] init];
        [installation install];
        [installation sendAllReports];
    });
    return YES;
}

- (void)crash {
    int* p = 0;
    *p = 0;
}

- (void)reportUserException:(NSString *)name
                     reason:(NSString *)reason
                   language:(NSString *)language
                 lineOfCode:(NSString *)lineOfCode
                 stackTrace:(NSArray *)stackTrace
              logAllThreads:(BOOL)logAllThreads
           terminateProgram:(BOOL)terminateProgram {
    if (nil == installation) {
        [SentryLog logWithMessage:@"KSCrash has not been initialized, call startCrashHandlerWithError" andLevel:kSentryLogLevelError];
        return;
    }
    [KSCrash.sharedInstance reportUserException:name
                                         reason:reason
                                       language:language
                                     lineOfCode:lineOfCode stackTrace:stackTrace
                                  logAllThreads:logAllThreads
                               terminateProgram:terminateProgram];
    [installation sendAllReports];
}

#else

- (void)reportUserException:(NSString *)name
                     reason:(NSString *)reason
                   language:(NSString *)language
                 lineOfCode:(NSString *)lineOfCode
                 stackTrace:(NSArray *)stackTrace
              logAllThreads:(BOOL)logAllThreads
           terminateProgram:(BOOL)terminateProgram {
    [SentryLog logWithMessage:@"Cannot report userException without KSCrash dependency" andLevel:kSentryLogLevelError];
}

- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error {
    NSString *message = @"KSCrashHandler not started - Make sure you added KSCrash as a dependency";
    [SentryLog logWithMessage:message andLevel:kSentryLogLevelError];
    if (nil != error) {
        *error = NSErrorFromSentryError(kSentryErrorKSCrashNotInstalledError, message);
    }
    return NO;
}

- (void)crash {
    [SentryLog logWithMessage:@"Would have crashed - but since KSCrash is not linked we do nothing." andLevel:kSentryLogLevelDebug];
}

#endif

@end

NS_ASSUME_NONNULL_END
