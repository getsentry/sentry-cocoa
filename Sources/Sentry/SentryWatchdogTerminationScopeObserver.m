#import "SentryWatchdogTerminationScopeObserver.h"

#if SENTRY_HAS_UIKIT

#    import <SentryBreadcrumb.h>
#    import <SentryFileManager.h>
#    import <SentryLogC.h>
#    import <SentrySwift.h>
#    import <SentryWatchdogTerminationBreadcrumbProcessor.h>

@interface SentryWatchdogTerminationScopeObserver ()

@property (nonatomic, strong) SentryWatchdogTerminationBreadcrumbProcessor *breadcrumbProcessor;
@property (nonatomic, strong) SentryWatchdogTerminationContextProcessor *contextProcessor;
@property (nonatomic, strong) SentryWatchdogTerminationUserProcessor *userProcessor;
@property (nonatomic, strong) SentryWatchdogTerminationTagsProcessor *tagsProcessor;
@property (nonatomic, strong) SentryWatchdogTerminationLevelProcessor *levelProcessor;

@end

@implementation SentryWatchdogTerminationScopeObserver

- (instancetype)
    initWithBreadcrumbProcessor:(SentryWatchdogTerminationBreadcrumbProcessor *)breadcrumbProcessor
               contextProcessor:(SentryWatchdogTerminationContextProcessor *)contextProcessor
                  userProcessor:(SentryWatchdogTerminationUserProcessor *)userProcessor
                  tagsProcessor:(SentryWatchdogTerminationTagsProcessor *)tagsProcessor
                 levelProcessor:(SentryWatchdogTerminationLevelProcessor *)levelProcessor
{
    if (self = [super init]) {
        self.breadcrumbProcessor = breadcrumbProcessor;
        self.contextProcessor = contextProcessor;
        self.userProcessor = userProcessor;
        self.tagsProcessor = tagsProcessor;
        self.levelProcessor = levelProcessor;
    }

    return self;
}

// PRAGMA MARK: - SentryScopeObserver

- (void)clear
{
    [self.breadcrumbProcessor clear];
    [self.contextProcessor clear];
    [self.userProcessor clear];
    [self.tagsProcessor clear];
    [self.levelProcessor clear];
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
    [self.levelProcessor setLevel:@(level)];
}

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags
{
    [self.tagsProcessor setTags:tags];
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
