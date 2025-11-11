#import "SentryDependencyContainerSwiftHelper.h"
#import "SentryClient+Private.h"
#import "SentryHub+Private.h"
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

+ (int)getSessionReplayMaskingStrategy:(SentryOptions *)options
{
    return (int)options.experimental.sessionReplayMaskingStrategy;
}

#endif // SENTRY_HAS_UIKIT

+ (NSString *)release:(SentryOptions *)options
{
    return options.releaseName;
}

+ (SentryLog *)beforeSendLog:(SentryLog *)log options:(SentryOptions *)options
{
    if (options.beforeSendLog) {
        return options.beforeSendLog(log);
    }
    return log;
}

+ (NSString *)environment:(SentryOptions *)options
{
    return options.environment;
}

+ (NSString *)cacheDirectoryPath:(SentryOptions *)options
{
    return options.cacheDirectoryPath;
}

+ (BOOL)enableLogs:(SentryOptions *)options
{
    return options.enableLogs;
}

+ (NSArray<NSString *> *)enabledFeatures:(SentryOptions *)options
{
    return [SentryEnabledFeaturesBuilder getEnabledFeaturesWithOptions:options];
}

+ (BOOL)sendDefaultPii:(SentryOptions *)options
{
    return options.sendDefaultPii;
}

+ (NSArray<NSString *> *)inAppIncludes:(SentryOptions *)options
{
    return options.inAppIncludes;
}

+ (SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    return SentryDependencyContainer.sharedInstance.dispatchQueueWrapper;
}

+ (void)dispatchSyncOnMainQueue:(void (^)(void))block
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchSyncOnMainQueue:block];
}

+ (nullable NSDate *)readTimestampLastInForeground
{
    SentryHubInternal *hub = [SentrySDKInternal currentHub];
    return [[[hub getClient] fileManager] readTimestampLastInForeground];
}

+ (void)deleteTimestampLastInForeground
{
    SentryHubInternal *hub = [SentrySDKInternal currentHub];
    [[[hub getClient] fileManager] deleteTimestampLastInForeground];
}

+ (void)storeTimestampLastInForeground:(NSDate *)timestamp
{
    SentryHubInternal *hub = [SentrySDKInternal currentHub];
    [[[hub getClient] fileManager] storeTimestampLastInForeground:timestamp];
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
+ (BOOL)hasProfilingOptions
{
    return SentrySDKInternal.currentHub.client.options.profiling != nil;
}
#endif

@end
