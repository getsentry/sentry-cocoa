#import "SentryHttpInterceptor+Private.h"
#import "SentryHub+Private.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentryTraceHeader.h"

@interface
SentryHttpInterceptor ()

@property (nullable, nonatomic, strong) NSURLSession *session;

+ (void)configureSessionConfiguration:(NSURLSessionConfiguration *)configuration;

- (NSURLSession *)createSession;

@end

@implementation SentryHttpInterceptor

+ (void)configureSessionConfiguration:(NSURLSessionConfiguration *)configuration
{
    if (configuration == nil)
        return;

    NSMutableArray *protocolClasses = configuration.protocolClasses != nil
        ? [NSMutableArray arrayWithArray:[configuration protocolClasses]]
        : [[NSMutableArray alloc] init];

    if (![protocolClasses containsObject:[self class]]) {
        // Adding SentryHTTPInterceptor at index 0 of the protocol list to be the first to
        // intercept.
        [protocolClasses insertObject:[self class] atIndex:0];
    }

    configuration.protocolClasses = protocolClasses;
}

// Documentation says that the method that takes a task parameter are preferred by the system to
// those that do not. But for the iOS versions we support `canInitWithTask:` does not work well.
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    // Intercept the request if it is a http/https request
    // not targeting Sentry and there is transaction in the scope.
    NSNumber *intercepted = [NSURLProtocol propertyForKey:SENTRY_INTERCEPTED_REQUEST
                                                inRequest:request];
    if (intercepted != nil && [intercepted boolValue])
        return NO;

    NSURL *apiUrl = [NSURL URLWithString:SentrySDK.options.dsn];
    if ([request.URL.host isEqualToString:apiUrl.host] &&
        [request.URL.path containsString:apiUrl.path])
        return NO;

    if (SentrySDK.currentHub.scope.span == nil)
        return NO;

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
    [NSURLProtocol setProperty:@YES forKey:SENTRY_INTERCEPTED_REQUEST inRequest:newRequest];
    return newRequest;
}

- (NSURLSession *)createSession
{
    NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
    return [NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:nil];
}

- (void)startLoading
{
    self.session = [self createSession];
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
