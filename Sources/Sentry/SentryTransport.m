//
//  SentryTransport.m
//  Sentry
//
//  Created by Klemens Mantzos on 27.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryTransport.h>
#import <Sentry/SentrySDK.h>
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
#import "SentrySDK.h"
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

@property(nonatomic, strong) SentryFileManager *fileManager;
@property(nonatomic, strong) id <SentryRequestManager> requestManager;
@property(nonatomic, weak) SentryOptions *options;
@property(nonatomic, strong) NSDate *_Nullable rateLimitDeadline;

@end

@implementation SentryTransport

@synthesize maxEvents = _maxEvents;

- (id)initWithOptions:(SentryOptions *)options {
  if (self = [super init]) {
      self.options = options;
      NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
      NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
      self.requestManager = [[SentryQueueableRequestManager alloc] initWithSession:session];

      NSError* error = nil;
      self.fileManager = [[SentryFileManager alloc] initWithDsn:options.dsn didFailWithError:&error];
      if (nil != error) {
          [SentryLog logWithMessage:(error).localizedDescription andLevel:kSentryLogLevelError];
          return nil;
      }
      [self setupQueueing];
  }
  return self;
}

- (void)storeEvent:(SentryEvent *)event {
    [self.fileManager storeEvent:event];
}

- (void)    sendEvent:(SentryEvent *)event
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {

    NSError *requestError = nil;
    SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.options.dsn
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

    if (![self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SentryClient is disabled, event will be stored to send later." andLevel:kSentryLogLevelDebug];
        return;
    }

    if ([self isRateLimitActive]) {
        [SentryLog logWithMessage:@"SentryClient rate limit is active. event will be stored to send later." andLevel:kSentryLogLevelDebug];
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
            if ([self.options.enabled boolValue] && [_self.requestManager isReady]) {
                [_self sendAllStoredEvents];
            }
        }
        if (completionHandler) {
            completionHandler(error);
        }
    }];
}

- (BOOL)isRateLimitActive {
    if (nil == self.rateLimitDeadline) {
        return NO;
    }

    NSDate * now = [NSDate date];
    NSComparisonResult result = [now compare:self.rateLimitDeadline];

    if (result == NSOrderedAscending) {
        return YES;
    } else {
        self.rateLimitDeadline = nil;
        return NO;
    }

    return NO;
}

- (void)setMaxEvents:(NSUInteger)maxEvents {
    self.fileManager.maxEvents = maxEvents;
}

- (void)setupQueueing {
    __block SentryTransport *_self = self;
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
            [_self updateRateLimit:response];
            return YES;
        }
        // In all other cases we don't want to retry sending it and just discard the event
        return NO;
    };
}


- (void)updateRateLimit:(NSHTTPURLResponse *)response {
    self.rateLimitDeadline = [self parseRetryAfterHeader:response.allHeaderFields[@"Retry-After"]];
}

/**
 * parses value of HTTP Header "Retry-After" which in most cases is sent in
 * combination with HTTP status 429 Too Many Requests.
 *
 * Retry-After can hold seconds or a date. This date is used as the `rateLimitDeadline`.
 *
 * @return NSDate representation of Retry-After. nil if parsing was unsuccessful.
 */
- (NSDate * __nullable)parseRetryAfterHeader:(NSString *)retryAfterHeader {
    if (nil == retryAfterHeader) {
      return nil;
    }

    NSDate *now = [NSDate date];

    // try to parse as integer (seconds)
    double retryAfterSeconds = [retryAfterHeader doubleValue];

    if (0 != retryAfterSeconds) {
        [now dateByAddingTimeInterval:retryAfterSeconds];
        return now;
    }

    // try to parse as date
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];
    NSDate *retryAfterDate = [dateFormatter dateFromString:retryAfterHeader];

    // returns nil if parsing was unsuccessful
    return retryAfterDate;
}


- (void)  sendRequest:(SentryNSURLRequest *)request
withCompletionHandler:(_Nullable SentryRequestOperationFinished)completionHandler {
    [self.requestManager addRequest:request completionHandler:completionHandler];
}

- (void)sendAllStoredEvents {

    if (![self.requestManager isReady]) {
        return;
    }
    dispatch_group_t dispatchGroup = dispatch_group_create();

    for (NSDictionary<NSString *, id> *fileDictionary in [self.fileManager getAllStoredEvents]) {
        dispatch_group_enter(dispatchGroup);

        SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.options.dsn
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
