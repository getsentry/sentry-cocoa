//
//  SentryTransport.m
//  Sentry
//
//  Created by Klemens Mantzos on 27.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryTransport.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentrySDK.h>
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
#else
#import "SentryTransport.h"
#import "SentryClient.h"
#import "SentrySDK.h"
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
#endif

@interface SentryTransport ()

@property(nonatomic, strong) SentryDsn *dsn;
@property(nonatomic, strong) SentryFileManager *fileManager;
@property(nonatomic, strong) id <SentryRequestManager> requestManager;

@end

@implementation SentryTransport

@synthesize sampleRate = _sampleRate;
@synthesize maxEvents = _maxEvents;
@synthesize maxBreadcrumbs = _maxBreadcrumbs;

+ (instancetype)shared {
    static SentryTransport *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (id)init {
  if (self = [super init]) {
      NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
      NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
      self.requestManager = [[SentryQueueableRequestManager alloc] initWithSession:session];

      //SentryDsn *dsn = [SentrySDK.currentHub getClient].options.dsn;
      NSError* error = nil;
      self.fileManager = [[SentryFileManager alloc] initWithDsn:[SentrySDK.currentHub getClient].options.dsn didFailWithError:&error];
      if (nil != error) {
          [SentryLog logWithMessage:(error).localizedDescription andLevel:kSentryLogLevelError];
          return nil;
      }
      [self setupQueueing];
  }
  return self;
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

- (void)    sendEvent:(SentryEvent *)event
                scope:(SentryScope *)scope
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    [self sendEvent:event scope:scope useClientProperties:YES withCompletionHandler:completionHandler];
}

- (void)storeEvent:(SentryEvent *)event scope:(SentryScope *)scope {
    //[self prepareEvent:event useClientProperties:YES];
    [self prepareEvent:event scope:scope useClientProperties:YES];
    [self.fileManager storeEvent:event];
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
    NSString * environment = [SentrySDK.currentHub getClient].options.environment;
    if (nil != environment && nil == event.environment) {
        event.environment = environment;
    }

    NSString * releaseName = [SentrySDK.currentHub getClient].options.releaseName;
    if (nil != releaseName && nil == event.releaseName) {
        event.releaseName = releaseName;
    }

    NSString * dist = [SentrySDK.currentHub getClient].options.dist;
    if (nil != dist && nil == event.dist) {
        event.dist = dist;
    }
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
    SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:[SentrySDK.currentHub getClient].options.dsn
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

    if (![[SentrySDK.currentHub getClient].options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SentryClient is disabled, event will be stored to send later." andLevel:kSentryLogLevelDebug];
        return;
    }

    __block SentryTransport *_self = self;
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
            if ([[SentrySDK.currentHub getClient].options.enabled boolValue] && [_self.requestManager isReady]) {
                [_self sendAllStoredEvents];
            }
        }
        if (completionHandler) {
            completionHandler(error);
        }
    }];
}


- (void)setMaxEvents:(NSUInteger)maxEvents {
    self.fileManager.maxEvents = maxEvents;
}

- (void)setMaxBreadcrumbs:(NSUInteger)maxBreadcrumbs {
    self.fileManager.maxBreadcrumbs = maxBreadcrumbs;
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


- (void)  sendRequest:(SentryNSURLRequest *)request
withCompletionHandler:(_Nullable SentryRequestOperationFinished)completionHandler {
    if (nil != self.beforeSendRequest) {
        self.beforeSendRequest(request);
    }
    [self.requestManager addRequest:request completionHandler:completionHandler];
}

- (void)sendAllStoredEvents {

    if (![self.requestManager isReady]) {
        return;
    }
    dispatch_group_t dispatchGroup = dispatch_group_create();

    for (NSDictionary<NSString *, id> *fileDictionary in [self.fileManager getAllStoredEvents]) {
        dispatch_group_enter(dispatchGroup);

        SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:[SentrySDK.currentHub getClient].options.dsn
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

@end
