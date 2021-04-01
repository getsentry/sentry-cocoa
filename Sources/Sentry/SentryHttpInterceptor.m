#import "SentryHttpInterceptor.h"
#import "SentrySDK+Private.h"
#import "SentryHub.h"
#import "SentrySpan.h"

@interface SentryHttpInterceptor () <NSURLSessionDelegate>

@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic) id<SentrySpan> requestSpan;
@end

@implementation SentryHttpInterceptor

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return ![request.URL.host.lowercaseString containsString:@"sentry"] &&
    ([request.URL.scheme isEqualToString:@"http"] | [request.URL.scheme isEqualToString:@"https"]);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSURLSessionConfiguration* conf = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:nil];
    [[self.session dataTaskWithRequest:self.request] resume];
    
    id<SentrySpan> span = SentrySDK.currentHub.scope.span;
    self.requestSpan = [span startChildWithOperation:self.request.URL.path];
}

-(void)stopLoading {
    [self.session invalidateAndCancel];
    self.session = nil;
}

#pragma mark - NSURLSession Delegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        [self.requestSpan finishWithStatus:kSentrySpanStatusUnknownError];
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.requestSpan finishWithStatus:kSentrySpanStatusOk];
        [self.client URLProtocolDidFinishLoading:self];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

@end
