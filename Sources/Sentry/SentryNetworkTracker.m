#import "SentryNetworkTracker.h"
#import "SentryOptions+Private.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import <objc/runtime.h>

static NSString *const SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID
    = @"SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID";

@interface
SentryNetworkTracker ()

@property (nonatomic, strong) SentryPerformanceTracker *tracker;

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
    }
    return self;
}

- (void)urlSessionTaskResume:(NSURLSessionTask *)sessionTask
{
    NSURL *url = [[sessionTask currentRequest] URL];
    if (url == nil)
        return;

    NSURL *apiUrl = [NSURL URLWithString:SentrySDK.options.dsn];
    if ([url.host isEqualToString:apiUrl.host] && [url.path containsString:apiUrl.path])
        return;

    NSString *statePath = NSStringFromSelector(@selector(state));
    [sessionTask addObserver:self
                  forKeyPath:statePath
                     options:NSKeyValueObservingOptionNew
                     context:nil];

    SentrySpanId *spanId = [self.tracker startSpanWithName:url.absoluteString
                                                 operation:SENTRY_NETWORK_REQUEST_OPERATION];

    objc_setAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID, spanId,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(state))]) {
        NSURLSessionTask *sessionTask = object;
        if (sessionTask.state != NSURLSessionTaskStateRunning) {
            SentrySpanId *spanId
                = objc_getAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID);

            if (spanId != nil) {
                [self.tracker finishSpan:spanId withStatus:[self statusForSessionTask:sessionTask]];
                [sessionTask removeObserver:self forKeyPath:NSStringFromSelector(@selector(state))];
            }
        }
    }
}

- (SentrySpanStatus)statusForSessionTask:(NSURLSessionTask *)task
{
    switch (task.state) {
    case NSURLSessionTaskStateSuspended:
    case NSURLSessionTaskStateCanceling:
        return kSentrySpanStatusCancelled;
    case NSURLSessionTaskStateCompleted: {
        if (task.response != nil && [task.response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            return [self statusForResponse:response];
        }
    } break;
    case NSURLSessionTaskStateRunning:
        break;
    }
    return kSentrySpanStatusUndefined;
}

- (SentrySpanStatus)statusForResponse:(NSHTTPURLResponse *)response
{
    if (response.statusCode >= 200 && response.statusCode < 300) {
        return kSentrySpanStatusOk;
    }

    switch (response.statusCode) {
    case 400:
        return kSentrySpanStatusInvalidArgument;
    case 401:
        return kSentrySpanStatusUnauthenticated;
    case 403:
        return kSentrySpanStatusPermissionDenied;
    case 404:
        return kSentrySpanStatusNotFound;
    case 409:
        return kSentrySpanStatusCancelled;
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
