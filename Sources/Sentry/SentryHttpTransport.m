#import "SentryHttpTransport.h"
#import "SentrySDK.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryUser.h"
#import "SentryEvent.h"
#import "SentryNSURLRequest.h"
#import "SentryCrashInstallationReporter.h"
#import "SentryFileManager.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryCrash.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#import "SentryEnvelope.h"
#import "SentrySerialization.h"
#import "SentryDefaultRateLimits.h"

@interface SentryHttpTransport ()

@property(nonatomic, strong) SentryFileManager *fileManager;
@property(nonatomic, strong) id <SentryRequestManager> requestManager;
@property(nonatomic, weak) SentryOptions *options;
@property(nonatomic, strong) id <SentryRateLimits> rateLimits;

@end

@implementation SentryHttpTransport

- (id)initWithOptions:(SentryOptions *)options
    sentryFileManager:(SentryFileManager *)sentryFileManager
 sentryRequestManager:(id<SentryRequestManager>) sentryRequestManager
sentryRateLimits:(id<SentryRateLimits>) sentryRateLimits
{
  if (self = [super init]) {
      self.options = options;
      self.requestManager = sentryRequestManager;
      self.fileManager = sentryFileManager;
      self.rateLimits = sentryRateLimits;

      [self setupQueueing];
  }
  return self;
}

// TODO: needs refactoring
- (void)    sendEvent:(SentryEvent *)event
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    if (![self isReadyToSend:SentryEnvelopeItemTypeEvent]) {
        return;
    }
    
    NSError *requestError = nil;
    // TODO: We do multiple serializations here, we can improve this
    NSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.options.dsn
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

    [self sendRequest:request storedPath:storedEventPath envelope:nil  completionHandler:completionHandler];
}

// TODO: needs refactoring
- (void)sendEnvelope:(SentryEnvelope *)envelope
   withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    // TODO: Apply type based rate limiting
    if (![self isReadyToSend:@""]) {
        return;
    }
    
    NSError *requestError = nil;
    // TODO: We do multiple serializations here, we can improve this
    NSURLRequest *request = [[SentryNSURLRequest alloc] initEnvelopeRequestWithDsn:self.options.dsn
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
    NSString *storedEnvelopePath = [self.fileManager storeEnvelope:envelope];

    [self sendRequest:request storedPath:storedEnvelopePath envelope:envelope  completionHandler:completionHandler];
}

// TODO: This has to move somewhere else, we are missing the whole beforeSend flow
- (void)sendAllStoredEvents {
    // TODO: Apply type based rate limiting
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
    __block SentryHttpTransport *_self = self;
    self.shouldQueueEvent = ^BOOL(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        // Taken from Apple Docs:
        // If a response from the server is received, regardless of whether the
        // request completes successfully or fails, the response parameter
        // contains that information.
        if (response == nil) {
            // In case response is nil, we want to queue the event locally since
            // this indicates no internet connection
            return YES;
        }
        [_self.rateLimits update:response];
        
        // In all other cases we don't want to retry sending it and just discard the event
        return NO;
    };
}

- (void)sendRequest:(NSURLRequest *)request
storedPath:(NSString *)storedPath
envelope:(SentryEnvelope *)envelope
completionHandler:(_Nullable SentryRequestFinished)completionHandler {
    __block SentryHttpTransport *_self = self;
    [self sendRequest:request withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        if (self.shouldQueueEvent == nil || self.shouldQueueEvent(response, error) == NO) {
            // don't need to queue this -> it most likely got sent
            // thus we can remove the event from disk
            [_self.fileManager removeFileAtPath:storedPath];
            if (nil == error) {
                [_self sendAllStoredEvents];
            }
        }
        if (completionHandler) {
            completionHandler(error);
        }
    }];
}

- (void)sendRequest:(NSURLRequest *)request withCompletionHandler:(_Nullable SentryRequestOperationFinished)completionHandler {
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
- (BOOL)isReadyToSend:(NSString *_Nonnull)type {
    if (![self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SentryClient is disabled. (options.enabled = false)" andLevel:kSentryLogLevelDebug];
        return NO;
    }

    if ([self.rateLimits isRateLimitActive:type]) {
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
    // TODO: Apply type based rate limiting
    if (![self isReadyToSend:@""]) {
        return NO;
    }

    if (![self.requestManager isReady]) {
        return NO;
    }

    return YES;
}

@end
