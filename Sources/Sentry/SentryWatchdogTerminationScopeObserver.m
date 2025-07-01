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
@property (nonatomic, strong) SentryWatchdogTerminationTagsProcessorWrapper *tagsProcessor;
@property (nonatomic, strong) SentryWatchdogTerminationDistProcessorWrapper *distProcessor;
@property (nonatomic, strong)
    SentryWatchdogTerminationEnvironmentProcessorWrapper *environmentProcessor;

@end

@implementation SentryWatchdogTerminationScopeObserver

- (instancetype)
    initWithBreadcrumbProcessor:(SentryWatchdogTerminationBreadcrumbProcessor *)breadcrumbProcessor
               contextProcessor:(SentryWatchdogTerminationContextProcessorWrapper *)contextProcessor
                  userProcessor:(SentryWatchdogTerminationUserProcessorWrapper *)userProcessor
                  tagsProcessor:(SentryWatchdogTerminationTagsProcessorWrapper *)tagsProcessor
                  distProcessor:(SentryWatchdogTerminationDistProcessorWrapper *)distProcessor
           environmentProcessor:
               (SentryWatchdogTerminationEnvironmentProcessorWrapper *)environmentProcessor
{
    if (self = [super init]) {
        self.breadcrumbProcessor = breadcrumbProcessor;
        self.contextProcessor = contextProcessor;
        self.userProcessor = userProcessor;
        self.tagsProcessor = tagsProcessor;
        self.distProcessor = distProcessor;
        self.environmentProcessor = environmentProcessor;
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
    [self.distProcessor clear];
    [self.environmentProcessor clear];
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
    [self.distProcessor setDist:dist];
}

- (void)setEnvironment:(nullable NSString *)environment
{
    [self.environmentProcessor setEnvironment:environment];
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
