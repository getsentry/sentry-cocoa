#import "SentryFramesTrackingIntegration.h"
#import "PrivateSentrySDKOnly.h"
#import "SentryFramesTracker.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryFramesTrackingIntegration ()

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryFramesTracker *tracker;
#endif

@end

@implementation SentryFramesTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
#if SENTRY_HAS_UIKIT
    if (![self shouldBeEnabled:@[
            [[SentryOptionWithDescription alloc]
                initWithOption:options.enableAutoPerformanceTracking
                    optionName:@"enableAutoPerformanceTracking"],
            [[SentryOptionWithDescription alloc] initWithOption:options.isTracingEnabled
                                                     optionName:@"isTracingEnabled"],
        ]]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    self.tracker = [SentryFramesTracker sharedInstance];
    [self.tracker start];

#else
    [SentryLog
        logWithMessage:
            @"NO UIKit -> SentryFramesTrackingIntegration will not track slow and frozen frames."
              andLevel:kSentryLevelInfo];
#endif
}

#if SENTRY_HAS_UIKIT
- (BOOL)shouldBeEnabled:(NSArray<NSNumber *> *)options
{
    // If the cocoa SDK is being used by a hybrid SDK,
    // we let the hybrid SDK decide whether to track frames or not.
    if (PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode) {
        return YES;
    }

    return [super shouldBeEnabled:options];
}
#endif

- (void)uninstall
{
    [self stop];
}

- (void)stop
{
#if SENTRY_HAS_UIKIT
    if (nil != self.tracker) {
        [self.tracker stop];
    }
#endif
}

@end

NS_ASSUME_NONNULL_END
