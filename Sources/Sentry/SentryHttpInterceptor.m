#import <Sentry/Sentry.h>
#import "SentryHttpInterceptor.h"
#import "SentrySDK+Private.h"

@interface SentryHttpInterceptor () <NSURLSessionDelegate>

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation SentryHttpInterceptor

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSURL *apiUrl = [NSURL URLWithString:SentrySDK.options.dsn];
    NSURL *url = request.URL;
    
    return
        [url.host isEqualToString:apiUrl.host] &&
        [url.path containsString:apiUrl.path] &&
        ([request.URL.scheme isEqualToString:@"http"] ||
        [request.URL.scheme isEqualToString:@"https"]);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *newRequest = [request mutableCopy];
    //[newRequest addValue:@"" forHTTPHeaderField:@""];
    return newRequest;
}

- (void)startLoading {
    NSURLSessionConfiguration* conf = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:nil];
    [[self.session dataTaskWithRequest:self.request] resume];
}

-(void)stopLoading {
    [self.session invalidateAndCancel];
    self.session = nil;
}

#pragma mark - NSURLSession Delegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
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
