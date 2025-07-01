#import "SentryWatchdogTerminationScopeObserver.h"

#if SENTRY_HAS_UIKIT

#    import <SentryBreadcrumb.h>
#    import <SentryFileManager.h>
#    import <SentryLogC.h>
#    import <SentrySwift.h>
#    import <SentryWatchdogTerminationBreadcrumbProcessor.h>

@interface SentryWatchdogTerminationScopeObserver ()

@property (nonatomic, strong) SentryWatchdogTerminationBreadcrumbProcessor *breadcrumbProcessor;
@property (nonatomic, strong) SentryWatchdogTerminationContextProcessorWrapper *contextProcessor;
@property (nonatomic, strong) SentryWatchdogTerminationUserProcessorWrapper *userProcessor;

@end

@implementation SentryWatchdogTerminationScopeObserver

- (instancetype)
    initWithBreadcrumbProcessor:(SentryWatchdogTerminationBreadcrumbProcessor *)breadcrumbProcessor
               contextProcessor:(SentryWatchdogTerminationContextProcessorWrapper *)contextProcessor
                  userProcessor:(SentryWatchdogTerminationUserProcessorWrapper *)userProcessor
{
    if (self = [super init]) {
        self.breadcrumbProcessor = breadcrumbProcessor;
        self.contextProcessor = contextProcessor;
        self.userProcessor = userProcessor;
    }

    return self;
}

// PRAGMA MARK: - SentryScopeObserver

- (void)clear
{
    [self.breadcrumbProcessor clear];
    [self.contextProcessor clear];
    [self.userProcessor clear];
}

- (void)addSerializedBreadcrumb:(NSDictionary *)crumb
{
    [self.breadcrumbProcessor addSerializedBreadcrumb:crumb];
}

- (void)clearBreadcrumbs
{
    [self.breadcrumbProcessor clearBreadcrumbs];
}

- (void)setContext:(nullable NSDictionary<NSString *, id> *)context
{
    [self.contextProcessor setContext:context];
}

- (void)setDist:(nullable NSString *)dist
{
    // Left blank on purpose
}

- (void)setEnvironment:(nullable NSString *)environment
{
    // Left blank on purpose
}

- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras
{
    // Left blank on purpose
}

- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint
{
    // Left blank on purpose
}

- (void)setLevel:(enum SentryLevel)level
{
    // Left blank on purpose
}

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags
{
    // Left blank on purpose
}

- (void)setUser:(nullable SentryUser *)user
{
    [self.userProcessor setUser:user];
}

- (void)setTraceContext:(nullable NSDictionary<NSString *, id> *)traceContext
{
    // Left blank on purpose
}

@end

#endif // SENTRY_HAS_UIKIT
