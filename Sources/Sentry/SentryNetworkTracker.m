#import "SentryNetworkTracker.h"
#import "SentryHttpInterceptor+Private.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import "SentrySpan.h"
#import <objc/runtime.h>

static NSString *const SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID
    = @"SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID";

@interface
SentryNetworkTracker ()

@property (nonatomic, strong) SentryPerformanceTracker *tracker;
@property (nonatomic, assign) BOOL isEnabled;

@end

@implementation SentryNetworkTracker

+ (SentryNetworkTracker *)sharedInstance
{
    static SentryNetworkTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.tracker = SentryPerformanceTracker.shared;
        self.isEnabled = NO;
    }
    return self;
}

- (void)enable
{
    @synchronized(self) {
        self.isEnabled = YES;
    }
}

- (void)disable
{
    @synchronized(self) {
        self.isEnabled = NO;
    }
}

- (void)urlSessionTaskResume:(NSURLSessionTask *)sessionTask
{
    @synchronized(self) {
        if (!self.isEnabled) {
            return;
        }
    }

    // We need to check if this request was created by SentryHTTPInterceptor so we don't end up with
    // two spans for the same request.
    NSNumber *intercepted = [NSURLProtocol propertyForKey:SENTRY_INTERCEPTED_REQUEST
                                                inRequest:[sessionTask currentRequest]];
    if (intercepted != nil && [intercepted boolValue])
        return;

    // SDK not enabled no need to continue
    if (SentrySDK.options == nil) {
        return;
    }

    NSURL *url = [[sessionTask currentRequest] URL];

    if (url == nil || ![self isTaskSupported:sessionTask])
        return;

    // Don't measure requests to Sentry's backend
    NSURL *apiUrl = [NSURL URLWithString:SentrySDK.options.dsn];
    if ([url.host isEqualToString:apiUrl.host] && [url.path containsString:apiUrl.path])
        return;

    SentrySpanId *spanId =
        [self.tracker startChildSpanWithName:[NSString stringWithFormat:@"%@ %@",
                                                       sessionTask.currentRequest.HTTPMethod, url]
                                   operation:SENTRY_NETWORK_REQUEST_OPERATION];

    // startChildSpan only create a span if there is an active transaction,
    // otherwise we have nothing else to do here.
    if (spanId == nil)
        return;

    objc_setAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID, spanId,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSString *statePath = NSStringFromSelector(@selector(state));
    [sessionTask addObserver:self
                  forKeyPath:statePath
                     options:NSKeyValueObservingOptionNew
                     context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(state))]) {
        NSURLSessionTask *sessionTask = object;
        if (sessionTask.state != NSURLSessionTaskStateRunning) {
            SentrySpanId *spanId;
            @synchronized(sessionTask) {
                spanId = objc_getAssociatedObject(
                    sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID);
                // We'll just go through once
                objc_setAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID, nil,
                    OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }

            if (spanId != nil) {
                id<SentrySpan> span = [self.tracker getSpan:spanId];
                NSInteger responseStatusCode = [self urlResponseStatusCode:sessionTask.response];

                if (responseStatusCode != -1) {
                    [span setDataValue:[NSNumber numberWithInteger:responseStatusCode]
                                forKey:@"http.status_code"];
                }

                [self.tracker finishSpan:spanId withStatus:[self statusForSessionTask:sessionTask]];
                [sessionTask removeObserver:self forKeyPath:NSStringFromSelector(@selector(state))];
                [SentryLog logWithMessage:@"Finished HTTP span for sessionTask"
                                 andLevel:kSentryLevelDebug];
            }
        }
    }
}

- (NSInteger)urlResponseStatusCode:(NSURLResponse *)response
{
    if (response != nil && [response isKindOfClass:[NSHTTPURLResponse class]]) {
        return ((NSHTTPURLResponse *)response).statusCode;
    }
    return -1;
}

- (SentrySpanStatus)statusForSessionTask:(NSURLSessionTask *)task
{
    switch (task.state) {
    case NSURLSessionTaskStateSuspended:
        return kSentrySpanStatusAborted;
    case NSURLSessionTaskStateCanceling:
        return kSentrySpanStatusCancelled;
    case NSURLSessionTaskStateCompleted: {
        return task.error != nil
            ? kSentrySpanStatusUnknownError
            : [self spanStatusForHttpResponseStatusCode:[self urlResponseStatusCode:task.response]];
    } break;
    case NSURLSessionTaskStateRunning:
        break;
    }
    return kSentrySpanStatusUndefined;
}

- (BOOL)isTaskSupported:(NSURLSessionTask *)task
{
    // Since streams are usually created to stay connected we don't measure this type of data
    // transfer.
    return [task isKindOfClass:[NSURLSessionDataTask class]] ||
        [task isKindOfClass:[NSURLSessionDownloadTask class]] ||
        [task isKindOfClass:[NSURLSessionUploadTask class]];
}

// https://develop.sentry.dev/sdk/event-payloads/span/
- (SentrySpanStatus)spanStatusForHttpResponseStatusCode:(NSInteger)statusCode
{
    if (statusCode >= 200 && statusCode < 300) {
        return kSentrySpanStatusOk;
    }

    switch (statusCode) {
    case 400:
        return kSentrySpanStatusInvalidArgument;
    case 401:
        return kSentrySpanStatusUnauthenticated;
    case 403:
        return kSentrySpanStatusPermissionDenied;
    case 404:
        return kSentrySpanStatusNotFound;
    case 409:
        return kSentrySpanStatusAborted;
    case 429:
        return kSentrySpanStatusResourceExhausted;
    case 500:
        return kSentrySpanStatusInternalError;
    case 501:
        return kSentrySpanStatusUnimplemented;
    case 503:
        return kSentrySpanStatusUnavailable;
    case 504:
        return kSentrySpanStatusDeadlineExceeded;
    }
    return kSentrySpanStatusUndefined;
}

@end
