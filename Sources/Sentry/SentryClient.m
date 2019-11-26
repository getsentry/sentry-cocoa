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
#import <Sentry/SentryBreadcrumbs.h>
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
#import "SentryBreadcrumbs.h"
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

@property(nonatomic, strong) SentryDsn *dsn;
@property(nonatomic, strong) SentryFileManager *fileManager;
@property(nonatomic, strong) id <SentryRequestManager> requestManager;

@end

@implementation SentryClient

@synthesize options = _options;
@synthesize sampleRate = _sampleRate;
@synthesize maxEvents = _maxEvents;
@synthesize maxBreadcrumbs = _maxBreadcrumbs;
@dynamic logLevel;

#pragma mark Initializer

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                         didFailWithError:(NSError *_Nullable *_Nullable)error {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    return [self initWithOptions:options
                  requestManager:[[SentryQueueableRequestManager alloc] initWithSession:session]
                didFailWithError:error];
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

// TODO(fetzig): add method getOptions()

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                           requestManager:(id <SentryRequestManager>)requestManager
                         didFailWithError:(NSError *_Nullable *_Nullable)error {
    if (self = [super init]) {
        //[self restoreContextBeforeCrash];
        [self setupQueueing];
//        _extra = [NSDictionary new];
//        _tags = [NSDictionary new];

        self.options = options;
        
//        if (nil == options.enabled) {
//            self.enabled = @YES;
//        } else {
//            self.enabled = sentryOptions.enabled;
//        }
//        self.dsn = sentryOptions.dsn;
//        self.environment = sentryOptions.environment;
//        self.releaseName = sentryOptions.releaseName;
//        self.dist = sentryOptions.dist;
        
        self.requestManager = requestManager;
        if (logLevel > 1) { // If loglevel is set > None
            NSLog(@"Sentry Started -- Version: %@", self.class.versionString);
        }
        self.fileManager = [[SentryFileManager alloc] initWithDsn:self.dsn didFailWithError:error];
        if (nil != error && nil != *error) {
            [SentryLog logWithMessage:(*error).localizedDescription andLevel:kSentryLogLevelError];
            return nil;
        }
        
        // We want to send all stored events on start up
        if ([self.enabled boolValue] && [self.requestManager isReady]) {
            [self sendAllStoredEvents];
        }
    }
    return self;
}

- (void)setupQueueing {
    self.shouldQueueEvent = ^BOOL(SentryEvent *_Nonnull event, NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        // Taken from Apple Docs:
        // If a response from the server is received, regardless of whether the request completes successfully or fails,
        // the response parameter contains that information.
        if (response == nil) {
            // In case response is nil, we want to queue the event locally since this
            // indicates no internet connection
            return YES;
        } else if ([response statusCode] == 429) {
            [SentryLog logWithMessage:@"Rate limit reached, event will be stored and sent later" andLevel:kSentryLogLevelError];
            return YES;
        }
        // In all other cases we don't want to retry sending it and just discard the event
        return NO;
    };
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

- (void)sendEvent:(SentryEvent *)event scope:(SentryScope *)scope withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    [self sendEvent:event scope:scope useClientProperties:YES withCompletionHandler:completionHandler];
}

- (void)prepareEvent:(SentryEvent *)event
               scope:(SentryScope *)scope
 useClientProperties:(BOOL)useClientProperties {
    NSParameterAssert(event);
    if (useClientProperties) {
        [self setSharedPropertiesOnEvent:event scope:scope];
    }

    if (nil != self.beforeSerializeEvent) {
        self.beforeSerializeEvent(event);
    }
}

- (void)storeEvent:(SentryEvent *)event scope:(SentryScope *)scope {
    //[self prepareEvent:event useClientProperties:YES];
    [self prepareEvent:event scope:scope useClientProperties:YES];
    [self.fileManager storeEvent:event];
}

- (void)    sendEvent:(SentryEvent *)event
                scope:(SentryScope *)scope
  useClientProperties:(BOOL)useClientProperties
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    [self prepareEvent:event scope:scope useClientProperties:useClientProperties];

    if (nil != self.shouldSendEvent && !self.shouldSendEvent(event)) {
        NSString *message = @"SentryClient shouldSendEvent returned NO so we will not send the event";
        [SentryLog logWithMessage:message andLevel:kSentryLogLevelDebug];
        if (completionHandler) {
            completionHandler(NSErrorFromSentryError(kSentryErrorEventNotSent, message));
        }
        return;
    }

    NSError *requestError = nil;
    SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.dsn
                                                                             andEvent:event
                                                                     didFailWithError:&requestError];
    if (nil != requestError) {
        [SentryLog logWithMessage:requestError.localizedDescription andLevel:kSentryLogLevelError];
        if (completionHandler) {
            completionHandler(requestError);
        }
        return;
    }

    NSString *storedEventPath = [self.fileManager storeEvent:event];
    
    if (![self.enabled boolValue]) {
        [SentryLog logWithMessage:@"SentryClient is disabled, event will be stored to send later." andLevel:kSentryLogLevelDebug];
        return;
    }
    
    __block SentryClient *_self = self;
    [self sendRequest:request withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        // We check if we should leave the event locally stored and try to send it again later
        if (self.shouldQueueEvent == nil || self.shouldQueueEvent(event, response, error) == NO) {
            [_self.fileManager removeFileAtPath:storedEventPath];
        }
        if (nil == error) {
            _self.lastEvent = event;
            [NSNotificationCenter.defaultCenter postNotificationName:@"Sentry/eventSentSuccessfully"
                                                              object:nil
                                                            userInfo:[event serialize]];
            // Send all stored events in background if the queue is ready
            if ([_self.enabled boolValue] && [_self.requestManager isReady]) {
                [_self sendAllStoredEvents];
            }
        }
        if (completionHandler) {
            completionHandler(error);
        }
    }];
}

- (void)  sendRequest:(SentryNSURLRequest *)request
withCompletionHandler:(_Nullable SentryRequestOperationFinished)completionHandler {
    if (nil != self.beforeSendRequest) {
        self.beforeSendRequest(request);
    }
    [self.requestManager addRequest:request completionHandler:completionHandler];
}

- (void)sendAllStoredEvents {
    dispatch_group_t dispatchGroup = dispatch_group_create();

    for (NSDictionary<NSString *, id> *fileDictionary in [self.fileManager getAllStoredEvents]) {
        dispatch_group_enter(dispatchGroup);

        SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.dsn
                                                                                  andData:fileDictionary[@"data"]
                                                                         didFailWithError:nil];
        [self sendRequest:request withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            if (nil == error) {
                NSDictionary *serializedEvent = [NSJSONSerialization JSONObjectWithData:fileDictionary[@"data"]
                                                                                options:0
                                                                                  error:nil];
                if (nil != serializedEvent) {
                    [NSNotificationCenter.defaultCenter postNotificationName:@"Sentry/eventSentSuccessfully"
                                                                      object:nil
                                                                    userInfo:serializedEvent];
                }
            }
            // We want to delete the event here no matter what (if we had an internet connection)
            // since it has been tried already
            if (response != nil) {
                [self.fileManager removeFileAtPath:fileDictionary[@"path"]];
            }

            dispatch_group_leave(dispatchGroup);
        }];
    }

    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"Sentry/allStoredEventsSent"
                                                          object:nil
                                                        userInfo:nil];
    });
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
        event.breadcrumbsSerialized = [scope.breadcrumbs serialize];
    }

    if (nil == event.infoDict) {
        event.infoDict = [[NSBundle mainBundle] infoDictionary];
    }
    
    if (nil != self.environment && nil == event.environment) {
        event.environment = self.environment;
    }
    
    if (nil != self.releaseName && nil == event.releaseName) {
        event.releaseName = self.releaseName;
    }
    
    if (nil != self.dist && nil == event.dist) {
        event.dist = self.dist;
    }
}

- (void)appendStacktraceToEvent:(SentryEvent *)event {
    if (nil != self._snapshotThreads && nil != self._debugMeta) {
        event.threads = self._snapshotThreads;
        event.debugMeta = self._debugMeta;
    }
}

#pragma mark Global properties

- (void)setReleaseName:(NSString *_Nullable)releaseName {
    _releaseName = releaseName;
}
    
- (void)setDist:(NSString *_Nullable)dist {
    _dist = dist;
}
    
- (void)setEnvironment:(NSString *_Nullable)environment {
    _environment = environment;
}

- (void)clearContext {
    [self setReleaseName:nil];
    [self setDist:nil];
    [self setEnvironment:nil];
}

- (void)setSampleRate:(float)sampleRate {
    if (sampleRate < 0 || sampleRate > 1) {
        [SentryLog logWithMessage:@"sampleRate must be between 0.0 and 1.0" andLevel:kSentryLogLevelError];
        return;
    }
    _sampleRate = sampleRate;
    self.shouldSendEvent = ^BOOL(SentryEvent *_Nonnull event) {
        return (sampleRate >= ((double)arc4random() / 0x100000000));
    };
}

- (void)setMaxEvents:(NSUInteger)maxEvents {
    self.fileManager.maxEvents = maxEvents;
}

- (void)setMaxBreadcrumbs:(NSUInteger)maxBreadcrumbs {
    self.fileManager.maxBreadcrumbs = maxBreadcrumbs;
}

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
