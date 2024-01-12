#import <Foundation/Foundation.h>

@interface
NSURLSessionTask (Sentry)

- (nullable NSString *)sentry_graphQLOperationName;

@end
