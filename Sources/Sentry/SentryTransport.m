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
#import <Sentry/SentryEnvelope.h>
#import <Sentry/SentrySerialization.h>
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
#import "SentryEnvelope.m"
#import "SentrySerialization.h"
#endif

@interface SentryTransport ()

@property(nonatomic, strong) SentryFileManager *fileManager;
@property(nonatomic, strong) id <SentryRequestManager> requestManager;
@property(nonatomic, weak) SentryOptions *options;

/**
 * datetime until we keep radio silence. Populated when response has HTTP 429
 * and "Retry-After" header -> rate limit exceeded.
 */
@property(atomic, strong) NSDate *_Nullable radioSilenceDeadline;

@end

@implementation SentryTransport

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

// TODO: needs refactoring
- (void)    sendEvent:(SentryEvent *)event
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    if (![self isReadyToSend]) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"We are hard rate limited, will drop event. Until: %@", self.radioSilenceDeadline] andLevel:kSentryLogLevelError];
        return;
    }
    
    NSError *requestError = nil;
    // TODO: We do multiple serializations here, we can improve this
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

    // TODO: We do multiple serializations here, we can improve this
    NSString *storedEventPath = [self.fileManager storeEvent:event];

    __block SentryTransport *_self = self;
    [self sendRequest:request withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        if (self.shouldQueueEvent == nil || self.shouldQueueEvent(nil, response, error) == NO) {
            // don't need to queue this -> it most likely got sent
            // thus we can remove the event from disk
            [_self.fileManager removeFileAtPath:storedEventPath];
            if (nil == error) {
                [_self sendAllStoredEvents];
            }
        }
        if (completionHandler) {
            completionHandler(error);
        }
    }];
}

// TODO: needs refactoring
- (void)    sendEnvelope:(SentryEnvelope *)envelope
   withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    if (![self isReadyToSend]) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"We are hard rate limited, will drop event. Until: %@", self.radioSilenceDeadline] andLevel:kSentryLogLevelError];
        return;
    }
    
    NSError *requestError = nil;
    // TODO: We do multiple serializations here, we can improve this
    SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.options.dsn
                                                                              andData:[SentrySerialization dataWithEnvelope:envelope options:0 error:&requestError]
                                                                     didFailWithError:&requestError];
    if (nil != requestError) {
        [SentryLog logWithMessage:requestError.localizedDescription andLevel:kSentryLogLevelError];
        if (completionHandler) {
            completionHandler(requestError);
        }
        return;
    }

    // TODO: We do multiple serializations here, we can improve this
    NSString *storedEventPath = [self.fileManager storeEnvelope:envelope];

    __block SentryTransport *_self = self;
    [self sendRequest:request withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        if (self.shouldQueueEvent == nil || self.shouldQueueEvent(envelope, response, error) == NO) {
            // don't need to queue this -> it most likely got sent
            // thus we can remove the event from disk
            [_self.fileManager removeFileAtPath:storedEventPath];
            if (nil == error) {
                [_self sendAllStoredEvents];
            }
        }
        if (completionHandler) {
            completionHandler(error);
        }
    }];
}

// TODO: This has to move somewhere else, we are missing the whole beforeSend flow
- (void)sendAllStoredEvents {
    if (![self isReadySendAllStoredEvents]) {
        return;
    }
    
    dispatch_group_t dispatchGroup = dispatch_group_create();
    for (NSDictionary<NSString *, id> *fileDictionary in [self.fileManager getAllStoredEvents]) {
        dispatch_group_enter(dispatchGroup);

        SentryNSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.options.dsn
                                                                                  andData:fileDictionary[@"data"]
                                                                         didFailWithError:nil];
        [self sendRequest:request withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            // TODO: How does beforeSend work here
            // We want to delete the event here no matter what (if we had an internet connection)
            // since it has been tried already.
            if (response != nil) {
                [self.fileManager removeFileAtPath:fileDictionary[@"path"]];
            }

            dispatch_group_leave(dispatchGroup);
        }];
    }
}

#pragma mark private methods

- (void)setupQueueing {
    __block SentryTransport *_self = self;
    self.shouldQueueEvent = ^BOOL(SentryEnvelope *envelope, NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        // Taken from Apple Docs:
        // If a response from the server is received, regardless of whether the
        // request completes successfully or fails, the response parameter
        // contains that information.
        if (response == nil) {
            // In case response is nil, we want to queue the event locally since
            // this indicates no internet connection
            return YES;
        } else if ([response statusCode] == 429) { // HTTP 429 Too Many Requests
            [SentryLog logWithMessage:@"Rate limit exceeded, event will be dropped" andLevel:kSentryLogLevelDebug];
            [_self updateRadioSilenceDealine:response];
            // In case of 429 we do not even want to store the event
            return NO;
        }
        // In all other cases we don't want to retry sending it and just discard the event
        return NO;
    };
}

- (void) sendRequest:(SentryNSURLRequest *)request withCompletionHandler:(_Nullable SentryRequestOperationFinished)completionHandler {
    [self.requestManager addRequest:request
                  completionHandler:^(NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        if (completionHandler) {
            completionHandler(response, error);
        }
    }];
}

/**
 * validation for `sendEvent:...`
 *
 * @return BOOL NO if options.enabled = false or rate limit exceeded
 */
- (BOOL)isReadyToSend {
    if (![self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SentryClient is disabled. (options.enabled = false)" andLevel:kSentryLogLevelDebug];
        return NO;
    }

    if ([self isRadioSilence]) {
        [SentryLog logWithMessage:@"SentryClient radio silence. 'Rate Limit' of DSN reached." andLevel:kSentryLogLevelDebug];
        return NO;
    }
    return YES;
}

/**
 * analog to isReadyToSend but with additional checks regarding batch upload.
 *
 * @return BOOL YES if ready to send requests.
 */
- (BOOL)isReadySendAllStoredEvents {
    if (![self isReadyToSend]) {
        return NO;
    }

    if (![self.requestManager isReady]) {
        return NO;
    }

    return YES;
}

#pragma mark rate limit

/**
 * used if actual time/deadline couldn't be determinded.
 */
- (NSDate *)defaultRadioSilenceDeadline {
    return [[NSDate date] dateByAddingTimeInterval:60];
}

/**
 * parses value of HTTP Header "Retry-After" which in most cases is sent in
 * combination with HTTP status 429 Too Many Requests.
 *
 * Retry-After value is a time-delta in seconds or a date.
 * In every case this method computes the date aka. `radioSilenceDeadline`.
 *
 * See RFC2616 for details on "Retry-After".
 * https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.37
 *
 * @return NSDate representation of Retry-After.
 *         As fallback `defaultRadioSilenceDeadline` is returned if parsing was
 *         unsuccessful.
 */
- (NSDate *)parseRetryAfterHeader:(NSString * __nullable)retryAfterHeader {
    if (nil == retryAfterHeader || 0 == [retryAfterHeader length]) {
        return [self defaultRadioSilenceDeadline];
    }

    NSDate *now = [NSDate date];

    // try to parse as double/seconds
    double retryAfterSeconds = [retryAfterHeader doubleValue];
    NSLog(@"parseRetryAfterHeader string '%@' to double: %f", retryAfterHeader, retryAfterSeconds);
    if (0 != retryAfterSeconds) {
        return [now dateByAddingTimeInterval:retryAfterSeconds];
    }

    // parsing as double/seconds failed, try to parse as date
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];
    NSDate *retryAfterDate = [dateFormatter dateFromString:retryAfterHeader];

    if (nil == retryAfterDate) {
        // parsing as seconds and date failed
        return [self defaultRadioSilenceDeadline];
    }
    return retryAfterDate;
}

- (BOOL)isRadioSilence {
    if (nil == self.radioSilenceDeadline) {
        return NO;
    }

    NSDate *now = [NSDate date];
    NSComparisonResult result = [now compare:self.radioSilenceDeadline];

    if (result == NSOrderedAscending) {
        return YES;
    } else {
        self.radioSilenceDeadline = nil;
        return NO;
    }

    return NO;
}

/**
 * When rate limit has been exceeded we updates the radio silence deadline and
 * therefor activates radio silence for at least
 * 60 seconds (default, see `defaultRadioSilenceDeadline`).
 */
- (void)updateRadioSilenceDealine:(NSHTTPURLResponse *)response {
    self.radioSilenceDeadline = [self parseRetryAfterHeader:response.allHeaderFields[@"Retry-After"]];
}

@end
