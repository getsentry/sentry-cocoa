#import "SentryURLRequestSnapshot.h"

@implementation SentryURLRequestSnapshot {
    NSURLRequest *_request;
}

+ (nullable instancetype)snapshotOfOriginalRequestOfTask:(NSURLSessionTask *)task
{
    return [self snapshotOfRequest:task.originalRequest];
}

+ (nullable instancetype)snapshotOfCurrentRequestOfTask:(NSURLSessionTask *)task
{
    return [self snapshotOfRequest:task.currentRequest];
}

+ (nullable instancetype)snapshotOfRequest:(nullable NSURLRequest *)request
{
    return request == nil ? nil : [[self alloc] initWithRequest:request];
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
