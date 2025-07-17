#import "SentryScope.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_CONTEXT_OS_KEY = @"os";
static NSString *const SENTRY_CONTEXT_DEVICE_KEY = @"device";

@interface SentryScope ()

// This is a workaround to make the traceId available in the Swift layer.
// Can't expose the SentryId directly for some reason.
@property (nonatomic, readonly) NSString *propagationContextTraceIdString;

- (NSDictionary<NSString *, id> *_Nullable)getContextForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
