#import "PrivateSentrySDKOnly.h"
#import "SentryAppStartMeasurement.h"
#import "SentryBreadcrumb+Private.h"
#import "SentryClient.h"
#import "SentryDebugImageProvider.h"
#import "SentryExtraContextProvider.h"
#import "SentryHub+Private.h"
#import "SentryInstallation.h"
#import "SentryInternalDefines.h"
#import "SentryMeta.h"
#import "SentryOptions.h"
#import "SentryProfiledTracerConcurrency.h"
#import "SentryProfiler+Private.h"
#import "SentryProfilerSerialization.h"
#import "SentrySDK+Private.h"
#import "SentrySerialization.h"
#import "SentrySwift.h"
#import "SentryThreadHandle.hpp"
#import "SentryUser+Private.h"
#import "SentryViewHierarchy.h"
#import <SentryBreadcrumb.h>
#import <SentryDependencyContainer.h>
#import <SentryFramesTracker.h>
#import <SentryScope+Private.h>
#import <SentryScreenshot.h>
#import <SentrySessionReplay.h>
#import <SentrySessionReplayIntegration.h>
#import <SentryUser.h>

@implementation PrivateSentrySDKOnly

static SentryOnAppStartMeasurementAvailable _onAppStartMeasurementAvailable;
static BOOL _appStartMeasurementHybridSDKMode = NO;
#if SENTRY_HAS_UIKIT
static BOOL _framesTrackingMeasurementHybridSDKMode = NO;
#endif // SENTRY_HAS_UIKIT

+ (void)storeEnvelope:(SentryEnvelope *)envelope
{
    [SentrySDK storeEnvelope:envelope];
}

+ (void)captureEnvelope:(SentryEnvelope *)envelope
{
    [SentrySDK captureEnvelope:envelope];
}

+ (nullable SentryEnvelope *)envelopeWithData:(NSData *)data
{
    return [SentrySerialization envelopeWithData:data];
}

+ (NSArray<SentryDebugMeta *> *)getDebugImages
{
    // maintains previous behavior for the same method call by also trying to gather crash info
    return [self getDebugImagesCrashed:YES];
}

+ (NSArray<SentryDebugMeta *> *)getDebugImagesCrashed:(BOOL)isCrash
{
    return [[SentryDependencyContainer sharedInstance].debugImageProvider
        getDebugImagesCrashed:isCrash];
}

+ (nullable SentryAppStartMeasurement *)appStartMeasurement
{
    return [SentrySDK getAppStartMeasurement];
}

+ (NSString *)installationID
{
    return [SentryInstallation idWithCacheDirectoryPath:self.options.cacheDirectoryPath];
}

+ (SentryOptions *)options
{
    SentryOptions *options = [[SentrySDK currentHub] client].options;
    if (options != nil) {
        return options;
    }
    return [[SentryOptions alloc] init];
}

+ (SentryOnAppStartMeasurementAvailable)onAppStartMeasurementAvailable
{
    return _onAppStartMeasurementAvailable;
}

+ (void)setOnAppStartMeasurementAvailable:
    (SentryOnAppStartMeasurementAvailable)onAppStartMeasurementAvailable
{
    _onAppStartMeasurementAvailable = onAppStartMeasurementAvailable;
}

+ (BOOL)appStartMeasurementHybridSDKMode
{
    return _appStartMeasurementHybridSDKMode;
}

+ (void)setAppStartMeasurementHybridSDKMode:(BOOL)appStartMeasurementHybridSDKMode
{
    _appStartMeasurementHybridSDKMode = appStartMeasurementHybridSDKMode;
}

+ (void)setSdkName:(NSString *)sdkName andVersionString:(NSString *)versionString
{
    SentryMeta.sdkName = sdkName;
    SentryMeta.versionString = versionString;
}

+ (void)setSdkName:(NSString *)sdkName
{
    SentryMeta.sdkName = sdkName;
}

+ (NSString *)getSdkName
{
    return SentryMeta.sdkName;
}

+ (NSString *)getSdkVersionString
{
    return SentryMeta.versionString;
}

+ (NSDictionary *)getExtraContext
{
    return [SentryDependencyContainer.sharedInstance.extraContextProvider getExtraContext];
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
+ (uint64_t)startProfilerForTrace:(SentryId *)traceId;
{
    [SentryProfiler startWithTracer:traceId];
    return SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
}

+ (nullable NSMutableDictionary<NSString *, id> *)collectProfileBetween:(uint64_t)startSystemTime
                                                                    and:(uint64_t)endSystemTime
                                                               forTrace:(SentryId *)traceId;
{
    NSMutableDictionary<NSString *, id> *payload = sentry_collectProfileData(
        startSystemTime, endSystemTime, traceId, [SentrySDK currentHub]);

    if (payload != nil) {
        payload[@"platform"] = SentryPlatformName;
        payload[@"transaction"] = @{
            @"active_thread_id" :
                [NSNumber numberWithLongLong:sentry::profiling::ThreadHandle::current()->tid()]
        };
    }

    return payload;
}

+ (void)discardProfilerForTrace:(SentryId *)traceId;
{
    sentry_discardProfilerForTracer(traceId);
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

+ (BOOL)framesTrackingMeasurementHybridSDKMode
{
#if SENTRY_HAS_UIKIT
    return _framesTrackingMeasurementHybridSDKMode;
#else
    SENTRY_LOG_DEBUG(@"PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode only works with "
                     @"UIKit enabled. Ensure you're "
                     @"using the right configuration of Sentry that links UIKit.");
    return NO;
#endif // SENTRY_HAS_UIKIT
}

+ (void)setFramesTrackingMeasurementHybridSDKMode:(BOOL)framesTrackingMeasurementHybridSDKMode
{
#if SENTRY_HAS_UIKIT
    _framesTrackingMeasurementHybridSDKMode = framesTrackingMeasurementHybridSDKMode;
#else
    SENTRY_LOG_DEBUG(@"PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode only works with "
                     @"UIKit enabled. Ensure you're "
                     @"using the right configuration of Sentry that links UIKit.");
#endif // SENTRY_HAS_UIKIT
}

+ (BOOL)isFramesTrackingRunning
{
#if SENTRY_HAS_UIKIT
    return SentryDependencyContainer.sharedInstance.framesTracker.isRunning;
#else
    SENTRY_LOG_DEBUG(@"PrivateSentrySDKOnly.isFramesTrackingRunning only works with UIKit enabled. "
                     @"Ensure you're "
                     @"using the right configuration of Sentry that links UIKit.");
    return NO;
#endif // SENTRY_HAS_UIKIT
}

+ (SentryScreenFrames *)currentScreenFrames
{
#if SENTRY_HAS_UIKIT
    return SentryDependencyContainer.sharedInstance.framesTracker.currentFrames;
#else
    SENTRY_LOG_DEBUG(
        @"PrivateSentrySDKOnly.currentScreenFrames only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#endif // SENTRY_HAS_UIKIT
}

+ (NSArray<NSData *> *)captureScreenshots
{
#if SENTRY_HAS_UIKIT
    return [SentryDependencyContainer.sharedInstance.screenshot appScreenshots];
#else
    SENTRY_LOG_DEBUG(
        @"PrivateSentrySDKOnly.captureScreenshots only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#endif // SENTRY_HAS_UIKIT
}

+ (NSData *)captureViewHierarchy
{
#if SENTRY_HAS_UIKIT
    return [SentryDependencyContainer.sharedInstance.viewHierarchy appViewHierarchy];
#else
    SENTRY_LOG_DEBUG(
        @"PrivateSentrySDKOnly.captureViewHierarchy only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#endif // SENTRY_HAS_UIKIT
}

+ (SentryUser *)userWithDictionary:(NSDictionary *)dictionary
{
    return [[SentryUser alloc] initWithDictionary:dictionary];
}

+ (SentryBreadcrumb *)breadcrumbWithDictionary:(NSDictionary *)dictionary
{
    return [[SentryBreadcrumb alloc] initWithDictionary:dictionary];
}

+ (void)captureReplay
{
#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION
    if (@available(iOS 16.0, *)) {
        NSArray *integrations = [[SentrySDK currentHub] installedIntegrations];
        SentrySessionReplayIntegration *replayIntegration;
        for (id obj in integrations) {
            if ([obj isKindOfClass:[SentrySessionReplayIntegration class]]) {
                replayIntegration = obj;
                break;
            }
        }

        [replayIntegration captureReplay];
    }
#else
    SENTRY_LOG_DEBUG(
        @"PrivateSentrySDKOnly.captureReplay only works with UIKit enabled and target is "
        @"not visionOS. Ensure you're using the right configuration of Sentry that links UIKit.");
#endif
}

+ (NSString *__nullable)getReplayId
{
    __block NSString *__nullable replayId;

    [SentrySDK configureScope:^(SentryScope *_Nonnull scope) { replayId = scope.replayId; }];

    return replayId;
}

+ (void)addReplayIgnoreClasses:(NSArray<Class> *_Nonnull)classes
{
#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        [SentryViewPhotographer.shared addIgnoreClasses:classes];
    } else {
        SENTRY_LOG_DEBUG(@"PrivateSentrySDKOnly.addIgnoreClasses only works with iOS 16 and newer");
    }
#else
    SENTRY_LOG_DEBUG(
        @"PrivateSentrySDKOnly.addReplayIgnoreClasses only works with UIKit enabled and target is "
        @"not visionOS. Ensure you're using the right configuration of Sentry that links UIKit.");
#endif
}

+ (void)addReplayRedactClasses:(NSArray<Class> *_Nonnull)classes
{
#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        [SentryViewPhotographer.shared addRedactClasses:classes];
    } else {
        SENTRY_LOG_DEBUG(
            @"PrivateSentrySDKOnly.addReplayRedactClasses only works with iOS 16 and newer");
    }
#else
    SENTRY_LOG_DEBUG(
        @"PrivateSentrySDKOnly.addReplayRedactClasses only works with UIKit enabled and target is "
        @"not visionOS. Ensure you're using the right configuration of Sentry that links UIKit.");
#endif
}

@end
