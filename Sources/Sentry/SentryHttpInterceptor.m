#import "SentryHttpInterceptor.h"
#import <Sentry/Sentry.h>

@interface
SentryHttpInterceptor () <NSURLSessionDelegate>

@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic) NSString *spanId;
@end

@implementation SentryHttpInterceptor

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return ![request.URL.host.lowercaseString containsString:@"sentry"]
        && ([request.URL.scheme isEqualToString:@"http"] ||
            [request.URL.scheme isEqualToString:@"https"]);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:nil];
    [[self.session dataTaskWithRequest:self.request] resume];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.spanId = [PerformanceTracker.instance addSpanWithOperation:self.request.URL.path
                                                              setActive:false];});
}

- (void)stopLoading
{
    [self.session invalidateAndCancel];
    self.session = nil;
}

#pragma mark - NSURLSession Delegate

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error
{
    SentrySpanStatus status;
    if (error) {
        status = kSentrySpanStatusUnknownError;
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        status = kSentrySpanStatusOk;
        [self.client URLProtocolDidFinishLoading:self];
    }
    dispatch_async(dispatch_get_main_queue(),
        ^{ [SentryPerformanceTracker.shared finishSpan:self.spanId withStatus:status]; });
}

- (void)URLSession:(NSURLSession *)session
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    [self.client URLProtocol:self
          didReceiveResponse:response
          cacheStoragePolicy:NSURLCacheStorageNotAllowed];

    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    [self.client URLProtocol:self didLoadData:data];
}

@end
