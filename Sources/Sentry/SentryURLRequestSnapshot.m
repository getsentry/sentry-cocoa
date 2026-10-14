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
    if (request == nil) {
        return nil;
    }
    return [[self alloc] initWithRequest:request];
}

- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if (self = [super init]) {
        _request = request;
        _URL = request.URL;
        _HTTPMethod = request.HTTPMethod;
        // Copies the whole dictionary for callers that pass all headers on; single-header lookups
        // go through -valueForHTTPHeaderField:, which matches names case-insensitively.
        // sentry-lint:disable avoid_all_header_fields
        _allHTTPHeaderFields = request.allHTTPHeaderFields;
        // sentry-lint:enable avoid_all_header_fields
        _HTTPBody = request.HTTPBody;
    }
    return self;
}

- (nullable NSString *)valueForHTTPHeaderField:(NSString *)field
{
    return [_request valueForHTTPHeaderField:field];
}

- (NSURLRequest *)requestCopy
{
    return _request;
}

@end
