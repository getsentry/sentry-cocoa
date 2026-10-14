#import "SentryURLRequestSnapshot.h"

@implementation SentryURLRequestSnapshot

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
        _URL = request.URL;
        _HTTPMethod = request.HTTPMethod;
        _HTTPBody = request.HTTPBody;
        // sentry-lint:disable avoid_all_header_fields
        _allHTTPHeaderFields = request.allHTTPHeaderFields;
        // sentry-lint:enable avoid_all_header_fields
    }
    return self;
}

- (nullable NSString *)valueForHTTPHeaderField:(NSString *)field
{
    // Matches names case-insensitively like -[NSURLRequest valueForHTTPHeaderField:], because the
    // snapshot no longer holds the request.
    // sentry-lint:disable avoid_all_header_fields
    for (NSString *name in _allHTTPHeaderFields) {
        if ([name caseInsensitiveCompare:field] == NSOrderedSame) {
            return _allHTTPHeaderFields[name];
        }
    }
    // sentry-lint:enable avoid_all_header_fields
    return nil;
}

@end
