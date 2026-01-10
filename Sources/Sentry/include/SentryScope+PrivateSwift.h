#import "SentryScope.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_CONTEXT_OS_KEY = @"os";
static NSString *const SENTRY_CONTEXT_DEVICE_KEY = @"device";
static NSString *const SENTRY_CONTEXT_APP_KEY = @"app";

// Added to only expose a limited sub-set of internal API needed in the Swift layer.
@interface SentryScope ()

@property (nonatomic, readonly) SentryId *propagationContextTraceId;

/**
 * Set global user -> thus will be sent with every event
 */
@property (atomic, strong) SentryUser *_Nullable userObject;

@property (nonatomic, nullable, copy) NSString *currentScreen;

- (NSArray<SentryBreadcrumb *> *)breadcrumbs;

- (NSDictionary<NSString *, id> *_Nullable)getContextForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
