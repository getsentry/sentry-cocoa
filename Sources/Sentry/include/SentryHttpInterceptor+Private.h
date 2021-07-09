#include "SentryHttpInterceptor.h"

static NSString* const SENTRY_INTERCEPTED_REQUEST = @"SENTRY_INTERCEPTED_REQUEST";

@interface SentryHttpInterceptor (private)

+ (void)configureSessionConfiguration:(NSURLSessionConfiguration *)configuration;

@end
