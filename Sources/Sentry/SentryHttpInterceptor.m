#import "SentryHttpInterceptor.h"
#import "SentryHub+Private.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentryTraceHeader.h"

@interface
SentryHttpInterceptor () <NSURLSessionDelegate>

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation SentryHttpInterceptor

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    // Intercept the request if it is a http/https request,
    // not targeting Sentry and there is transaction in the scope.

    NSURL *apiUrl = [NSURL URLWithString:SentrySDK.options.dsn];
    if ([apiUrl.host isEqualToString:apiUrl.host] && [apiUrl.path containsString:apiUrl.path])
        return false;
    if (SentrySDK.currentHub.scope.span == nil)
        return false;
    return ([request.URL.scheme isEqualToString:@"http"] ||
        [request.URL.scheme isEqualToString:@"https"]);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    id<SentrySpan> span = SentrySDK.currentHub.scope.span;
    if (span == nil)
        return request;

    NSMutableURLRequest *newRequest = [request mutableCopy];
    [newRequest addValue:[span toTraceHeader].value forHTTPHeaderField:SENTRY_TRACE_HEADER];

    return newRequest;
}

- (void)startLoading
{
    NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:nil];
    [[self.session dataTaskWithRequest:self.request] resume];
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
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
    }
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
