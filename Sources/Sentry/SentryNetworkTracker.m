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
            [self.tracker finishSpan:spanId];
            [sessionTask removeObserver:self forKeyPath:NSStringFromSelector(@selector(state))];
        }
    }
}

@end
