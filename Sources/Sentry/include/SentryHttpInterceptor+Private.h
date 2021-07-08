#include "SentryHttpInterceptor.h"

@interface SentryHttpInterceptor (private)

+ (void)configureSessionConfiguration:(NSURLSessionConfiguration *)configuration;

@end
