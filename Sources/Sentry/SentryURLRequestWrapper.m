#import "SentryURLRequestWrapper.h"
#import "SentryInternalDefines.h"

@implementation SentryURLRequestWrapper

+ (nullable instancetype)wrapperForOriginalRequestOfTask:(NSURLSessionTask *)task
{
    return [self wrapperForRequest:task.originalRequest];
}

+ (nullable instancetype)wrapperForCurrentRequestOfTask:(NSURLSessionTask *)task
{
    return [self wrapperForRequest:task.currentRequest];
}

+ (nullable instancetype)wrapperForRequest:(nullable NSURLRequest *)request
{
    if (request == nil) {
        return nil;
    }
    return [[self alloc] initWithRequest:SENTRY_UNWRAP_NULLABLE(NSURLRequest, request)];
}

- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if (self = [super init]) {
        _request = request;
    }
    return self;
}

- (nullable NSURL *)URL
{
    return _request.URL;
}

- (nullable NSString *)HTTPMethod
{
    return _request.HTTPMethod;
}

- (nullable NSData *)HTTPBody
{
    return _request.HTTPBody;
}

// sentry-lint:disable avoid_all_header_fields
- (nullable NSDictionary<NSString *, NSString *> *)allHTTPHeaderFields
{
    return _request.allHTTPHeaderFields;
}
// sentry-lint:enable avoid_all_header_fields

- (nullable NSString *)valueForHTTPHeaderField:(NSString *)field
{
    return [_request valueForHTTPHeaderField:field];
}

@end
