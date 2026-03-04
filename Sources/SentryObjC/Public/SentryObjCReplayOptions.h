#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_OBJC_REPLAY_SUPPORTED

typedef NS_ENUM(NSInteger, SentryReplayQuality) {
    SentryReplayQualityLow = 0,
    SentryReplayQualityMedium = 1,
    SentryReplayQualityHigh = 2
};

/**
 * Configuration options for Session Replay.
 *
 * @see SentryOptions
 */
@interface SentryReplayOptions : NSObject

@property (nonatomic, assign) float sessionSampleRate;
@property (nonatomic, assign) float onErrorSampleRate;
@property (nonatomic, assign) BOOL maskAllText;
@property (nonatomic, assign) BOOL maskAllImages;
@property (nonatomic, assign) SentryReplayQuality quality;
@property (nonatomic, copy) NSArray<Class> *maskedViewClasses;
@property (nonatomic, copy) NSArray<Class> *unmaskedViewClasses;
@property (nonatomic, copy) NSSet<NSString *> *excludedViewClasses;
@property (nonatomic, copy) NSSet<NSString *> *includedViewClasses;
@property (nonatomic, assign) BOOL enableViewRendererV2;
@property (nonatomic, assign) BOOL enableFastViewRendering;

- (void)excludeViewTypeFromSubtreeTraversal:(NSString *)viewType;
- (void)includeViewTypeInSubtreeTraversal:(NSString *)viewType;

@end

#endif // SENTRY_OBJC_REPLAY_SUPPORTED

NS_ASSUME_NONNULL_END
