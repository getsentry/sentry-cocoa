#import "SentryNetworkTracker.h"
#import "SentryPerformanceTracker.h"
#import <objc/runtime.h>

static NSString *const SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID
= @"SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID";

@implementation SentryNetworkTracker

+ (SentryNetworkTracker *)sharedInstance
{
    static SentryNetworkTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)urlSessionTaskResume:(NSURLSessionTask *)sessionTask
{
    NSURL * url = sessionTask.currentRequest.URL;
    if (self.sentryApiUrl != nil && [url.host isEqualToString:self.sentryApiUrl.host] && [url.path containsString:self.sentryApiUrl.path]) return;
    
    NSString * statePath = NSStringFromSelector(@selector(state));
    [sessionTask addObserver:self forKeyPath:statePath options:NSKeyValueObservingOptionNew context:nil];
    
    SentrySpanId * spanId = [SentryPerformanceTracker.shared startSpanWithName:url.absoluteString operation:SENTRY_NETWORK_REQUEST_OPERATION];
    
    objc_setAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID, spanId,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(state))])
    {
        NSURLSessionTask *sessionTask = object;
        if (sessionTask.state != NSURLSessionTaskStateRunning)
        {
            SentrySpanId *spanId = objc_getAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN_ID);
            [SentryPerformanceTracker.shared finishSpan:spanId];
            [sessionTask removeObserver:self forKeyPath:NSStringFromSelector(@selector(state))];
        }
    }
}

@end
