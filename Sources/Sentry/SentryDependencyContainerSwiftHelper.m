#import "SentryDependencyContainerSwiftHelper.h"
#import "SentryClient+Private.h"
#import "SentryDependencyContainer.h"
#import "SentryHub+Private.h"
#import "SentryOptions+Private.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

@implementation SentryDefaultRedactOptions
- (instancetype)initWithMaskAllText:(BOOL)maskAllText
                      maskAllImages:(BOOL)maskAllImages
                  maskedViewClasses:(NSArray<Class> *)maskedViewClasses
                unmaskedViewClasses:(NSArray<Class> *)unmaskedViewClasses
{
    if (self = [super init]) {
        _maskAllText = maskAllText;
        _maskAllImages = maskAllImages;
        _maskedViewClasses = maskedViewClasses;
        _unmaskedViewClasses = unmaskedViewClasses;
        return self;
    }
    return nil;
}

@end

@implementation SentryDependencyContainerSwiftHelper

#if SENTRY_HAS_UIKIT

+ (NSArray<UIWindow *> *)windows
{
    return [SentryDependencyContainer.sharedInstance.application getWindows];
}

+ (BOOL)fastViewRenderingEnabled:(SentryOptions *)options
{
    return options.screenshot.enableFastViewRendering;
}

+ (BOOL)viewRendererV2Enabled:(SentryOptions *)options
{
    return options.screenshot.enableViewRendererV2;
}

+ (SentryDefaultRedactOptions *)redactOptions:(SentryOptions *)options
{
    return [[SentryDefaultRedactOptions alloc]
        initWithMaskAllText:options.screenshot.maskAllText
              maskAllImages:options.screenshot.maskAllImages
          maskedViewClasses:options.screenshot.maskedViewClasses
        unmaskedViewClasses:options.screenshot.unmaskedViewClasses];
}

#endif // SENTRY_HAS_UIKIT

+ (SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    return SentryDependencyContainer.sharedInstance.dispatchQueueWrapper;
}

+ (void)dispatchSyncOnMainQueue:(void (^)(void))block
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchSyncOnMainQueue:block];
}

+ (id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper
{
    return SentryDependencyContainer.sharedInstance.objcRuntimeWrapper;
}

+ (SentryHub *)currentHub
{
    return SentrySDKInternal.currentHub;
}

+ (nullable NSDictionary *)systemInfo
{
    return SentryDependencyContainer.sharedInstance.crashReporter.systemInfo;
}

+ (BOOL)crashedLastLaunch
{
    return SentryDependencyContainer.sharedInstance.crashReporter.crashedLastLaunch;
}

+ (NSTimeInterval)activeDurationSinceLastCrash
{
    return SentryDependencyContainer.sharedInstance.crashReporter.activeDurationSinceLastCrash;
}

+ (nullable NSDate *)readTimestampLastInForeground
{
    SentryHub *hub = [SentrySDKInternal currentHub];
    return [[[hub getClient] fileManager] readTimestampLastInForeground];
}

+ (void)deleteTimestampLastInForeground
{
    SentryHub *hub = [SentrySDKInternal currentHub];
    [[[hub getClient] fileManager] deleteTimestampLastInForeground];
}

+ (void)storeTimestampLastInForeground:(NSDate *)timestamp
{
    SentryHub *hub = [SentrySDKInternal currentHub];
    [[[hub getClient] fileManager] storeTimestampLastInForeground:timestamp];
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
+ (BOOL)hasProfilingOptions
{
    return SentrySDKInternal.currentHub.client.options.profiling != nil;
}
#endif

@end
