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
@property(nonatomic, strong) NSDate *_Nullable radioSilenceDeadline;

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

    // FIXME fetzig: these checks (enabled and radio silence) have been moved to the top of this method. check if this is correct.
    if (![self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SentryClient is disabled, event will be stored to send later." andLevel:kSentryLogLevelDebug];
        return;
    }

    if ([self isRadioSilence]) {
        [SentryLog logWithMessage:@"SentryClient radio silence. 'Rate Limit' of DNS reached. Event will be stored to send later." andLevel:kSentryLogLevelDebug];
        return;
    }

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

    __block SentryTransport *_self = self;
    [self sendRequest:request withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {


        // FIXME fetzig: response processing is inconsistent, see `sendAllStoredEvents`. here is shouldQueueEvent checked. in case of no response the event is stored/queued[sic!]. the opposite happens when sent via `sendAllStoredEvents`. this makes sense when thinking about it (don't retry more than once). but needs at least a comment. check this!

        if (self.shouldQueueEvent == nil || self.shouldQueueEvent(event, response, error) == NO) {
            // don't need to queue this -> it most likely got sent
            // thus we can remove the event from disk
            [_self.fileManager removeFileAtPath:storedEventPath];
        }
        if (nil == error) {
            _self.lastEvent = event;
            [NSNotificationCenter.defaultCenter postNotificationName:@"Sentry/eventSentSuccessfully"
                                                              object:nil
                                                            userInfo:[event serialize]];
            [_self sendAllStoredEvents];
        }
        if (completionHandler) {
            completionHandler(error);
        }
    }];
}

- (BOOL)isRadioSilence {
    if (nil == self.radioSilenceDeadline) {
        return NO;
    }

    NSDate * now = [NSDate date];
    NSComparisonResult result = [now compare:self.radioSilenceDeadline];

    if (result == NSOrderedAscending) {
        return YES;
    } else {
        self.radioSilenceDeadline = nil;
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
        } else if ([response statusCode] == 429) { // HTTP 429 Too Many Requests
            [SentryLog logWithMessage:@"Rate limit exceeded, event will be stored and sent later" andLevel:kSentryLogLevelError];
            [_self updateRadioSilenceDealine:response];
            return YES;
        }
        // In all other cases we don't want to retry sending it and just discard the event
        return NO;
    };
}


/**
 * When rate limit has been exceeded we updates the radio silence deadline and
 * therefor activates radio silence for at least
 * 60 seconds (default, see `defaultRadioSilenceDeadline`).
 */
- (void)updateRadioSilenceDealine:(NSHTTPURLResponse *)response {
    if ([response statusCode] == 429) { // --> 429 only!
        self.radioSilenceDeadline = [self parseRetryAfterHeader:response.allHeaderFields[@"Retry-After"]];
    }
}

/**
 * used if actual time/deadline couldn't be determinded.
 */
- (NSDate *)defaultRadioSilenceDeadline {
    NSDate *now = [NSDate date];
    return [now dateByAddingTimeInterval:60];
}

/**
 * parses value of HTTP Header "Retry-After" which in most cases is sent in
 * combination with HTTP status 429 Too Many Requests.
 *
 * Retry-After value is a time-delta in seconds or a date.
 * In every case this method computes the date aka. `radioSilenceDeadline`.
 *
 * @return NSDate representation of Retry-After.
 *         As fallback "now + 1 minute" is returned if parsing was unsuccessful.
 */
- (NSDate *)parseRetryAfterHeader:(NSString * __nullable)retryAfterHeader {
    if (nil == retryAfterHeader || 0 == [retryAfterHeader length]) {
        return [self defaultRadioSilenceDeadline];
    }

    NSDate *now = [NSDate date];

    // try to parse as double
    double retryAfterSeconds = [retryAfterHeader doubleValue];
    NSLog(@"parseRetryAfterHeader 120 as string is this in double: %f", retryAfterSeconds);
    if (0 != retryAfterSeconds) {
        [now dateByAddingTimeInterval:retryAfterSeconds];
        return now;
    }

    // parsing as seconds failed, try to parse as date
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];
    NSDate *retryAfterDate = [dateFormatter dateFromString:retryAfterHeader];

    if (nil == retryAfterDate) {
        // parsing as seconds and date failed
        return [self defaultRadioSilenceDeadline];
    }
    return retryAfterDate;
}


- (void)  sendRequest:(SentryNSURLRequest *)request
withCompletionHandler:(_Nullable SentryRequestOperationFinished)completionHandler {
    [self.requestManager addRequest:request completionHandler:completionHandler];
}

- (BOOL) isReadyForAllEventsUpload {
    if (![self.options.enabled boolValue]) {
        return NO;
    }

    if ([self isRadioSilence]) {
        return NO;
    }

    if (![self.requestManager isReady]) {
        return NO;
    }

    return YES;
}

- (void)sendAllStoredEvents {
    if (![self isReadyForAllEventsUpload]) {
        return;
    }
    dispatch_group_t dispatchGroup = dispatch_group_create();

    for (NSDictionary<NSString *, id> *fileDictionary in [self.fileManager getAllStoredEvents]) {

        // NOTE: we could check for `isRadioSilence` to prevent more requests
        //       but this makes little to no difference since requests have most
        //       likely been triggered before the first response is processed.
        //       Amount of events stored will in most cases not be very big.

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

            // FIXME fetzig: response processing is inconsistent, see `sendEvent`. check this!

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
