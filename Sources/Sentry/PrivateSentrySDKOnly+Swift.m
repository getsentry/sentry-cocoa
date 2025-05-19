#import "PrivateSentrySDKOnly+Swift.h"
#import "SentrySwift.h"
#import "SentrySDK+Private.h"
#import "SentryHub+Private.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySessionReplayIntegration+Private.h"
#import "SentryTraceProfiler.h"
#import "SentryDependencyContainer.h"

@implementation PrivateSentrySDKOnly (Swift)

#if SENTRY_TARGET_PROFILING_SUPPORTED
+ (uint64_t)startProfilerForTrace:(SentryId *)traceId;
{
    [SentryTraceProfiler startWithTracer:traceId];
    return SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
}
#endif

#if SENTRY_TARGET_REPLAY_SUPPORTED

+ (UIView *)sessionReplayMaskingOverlay:(id<SentryRedactOptions>)options
{
    return [[SentryMaskingPreviewView alloc] initWithRedactOptions:options];
}

+ (nullable SentrySessionReplayIntegration *)getReplayIntegration
{

    NSArray *integrations = [[SentrySDK currentHub] installedIntegrations];
    SentrySessionReplayIntegration *replayIntegration;
    for (id obj in integrations) {
        if ([obj isKindOfClass:[SentrySessionReplayIntegration class]]) {
            replayIntegration = obj;
            break;
        }
    }

    return replayIntegration;
}

+ (void)captureReplay
{
    [[PrivateSentrySDKOnly getReplayIntegration] captureReplay];
}

+ (void)configureSessionReplayWith:(nullable id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
                screenshotProvider:(nullable id<SentryViewScreenshotProvider>)screenshotProvider
{
    [[PrivateSentrySDKOnly getReplayIntegration] configureReplayWith:breadcrumbConverter
                                                  screenshotProvider:screenshotProvider];
}

+ (NSString *__nullable)getReplayId
{
    __block NSString *__nullable replayId;

    [SentrySDK configureScope:^(SentryScope *_Nonnull scope) { replayId = scope.replayId; }];

    return replayId;
}

+ (void)addReplayIgnoreClasses:(NSArray<Class> *_Nonnull)classes
{
    [[PrivateSentrySDKOnly getReplayIntegration].viewPhotographer addIgnoreClasses:classes];
}

+ (void)addReplayRedactClasses:(NSArray<Class> *_Nonnull)classes
{
    [[PrivateSentrySDKOnly getReplayIntegration].viewPhotographer addRedactClasses:classes];
}

+ (void)setIgnoreContainerClass:(Class _Nonnull)containerClass
{
    [[PrivateSentrySDKOnly getReplayIntegration].viewPhotographer
        setIgnoreContainerClass:containerClass];
}

+ (void)setRedactContainerClass:(Class _Nonnull)containerClass
{
    [[PrivateSentrySDKOnly getReplayIntegration].viewPhotographer
        setRedactContainerClass:containerClass];
}

+ (void)setReplayTags:(NSDictionary<NSString *, id> *)tags
{
    [[PrivateSentrySDKOnly getReplayIntegration] setReplayTags:tags];
}

#endif

@end
