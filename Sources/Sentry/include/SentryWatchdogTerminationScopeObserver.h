#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class SentryWatchdogTerminationBreadcrumbProcessor;
@class SentryWatchdogTerminationAttributesProcessor;
@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

/**
 * This scope observer is used by the Watchdog Termination integration to write breadcrumbs to disk.
 * The overhead is ~0.015 seconds for 1000 breadcrumbs.
 * This class doesn't need to be thread safe as the scope already calls the scope observers in a
 * thread safe manner.
 */
@interface SentryWatchdogTerminationScopeObserver : NSObject
SENTRY_NO_INIT

- (instancetype)
    initWithBreadcrumbProcessor:(SentryWatchdogTerminationBreadcrumbProcessor *)breadcrumbProcessor
            attributesProcessor:(SentryWatchdogTerminationAttributesProcessor *)attributesProcessor;

- (void)setUser:(nullable SentryUser *)user;

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags;

- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras;

- (void)setContext:(nullable NSDictionary<NSString *, id> *)context;

- (void)setTraceContext:(nullable NSDictionary<NSString *, id> *)traceContext;

- (void)setDist:(nullable NSString *)dist;

- (void)setEnvironment:(nullable NSString *)environment;

- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint;

- (void)setLevel:(enum SentryLevel)level;

- (void)addSerializedBreadcrumb:(NSDictionary<NSString *, id> *)crumb;

- (void)clearBreadcrumbs;

- (void)clear;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
