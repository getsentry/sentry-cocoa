#include "SentryHttpInterceptor.h"

NS_ASSUME_NONNULL_BEGIN
static NSString *const SENTRY_INTERCEPTED_REQUEST = @"SENTRY_INTERCEPTED_REQUEST";

@interface SentryHttpInterceptor (private) <NSURLSessionDelegate, NSURLSessionTaskDelegate,
    NSURLSessionDataDelegate>

@property (nullable, nonatomic, strong) NSURLSession *session;

+ (void)configureSessionConfiguration:(NSURLSessionConfiguration *)configuration;

- (NSURLSession *)createSession;

@end
NS_ASSUME_NONNULL_END
