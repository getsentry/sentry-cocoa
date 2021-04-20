#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A class used to automatically track http requests.
 * You can used it by passing it in you URL Session configuration manually
 * or by turning on automatic instrumentation.
 */
@interface SentryHttpInterceptor : NSURLProtocol

@end

NS_ASSUME_NONNULL_END
