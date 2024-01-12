#import "NSURLSessionTask+Sentry.h"


@implementation
NSURLSessionTask (Sentry)

- (nullable NSString *)sentry_graphQLOperationName
{
    if (!self.originalRequest.HTTPBody) { return nil; }
    if (![[self.originalRequest valueForHTTPHeaderField:@"Content-Type"] isEqual: @"application/json"]) { return nil; }

    NSError *error = nil;
    id requestDictionary = [NSJSONSerialization JSONObjectWithData:self.originalRequest.HTTPBody options:0 error:&error];

    if (error) { return nil; }
    if (![requestDictionary isKindOfClass: [NSDictionary class]]) { return nil; } // Could be an array

    id operationName = [requestDictionary valueForKey:@"operationName"];
    if (![operationName isKindOfClass: [NSString class]]) { return nil; }
    if ([operationName length] == 0) { return nil; }

    return operationName;
}

@end
