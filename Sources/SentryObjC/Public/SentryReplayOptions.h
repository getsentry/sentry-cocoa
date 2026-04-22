#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_OBJC_REPLAY_SUPPORTED

/**
 * Video quality for session replay recordings.
 */
typedef NS_ENUM(NSInteger, SentryReplayQuality) {
    /** Low quality (lower file size, faster upload) */
    SentryReplayQualityLow = 0,
    /** Medium quality (balanced size and clarity) */
    SentryReplayQualityMedium = 1,
    /** High quality (larger file size, better clarity) */
    SentryReplayQualityHigh = 2
};

// See SentryFeedback.h for an explanation of why SentryObjC's public headers alias
// the plain class name to the Swift-mangled class exported by Sentry.framework.
#    if SWIFT_PACKAGE
@class _TtC11SentrySwift19SentryReplayOptions;
@compatibility_alias SentryReplayOptions _TtC11SentrySwift19SentryReplayOptions;
#    else
@class _TtC6Sentry19SentryReplayOptions;
@compatibility_alias SentryReplayOptions _TtC6Sentry19SentryReplayOptions;
#    endif

/**
 * Configuration options for Session Replay.
 *
 * Configure replay behavior, sampling rates, privacy settings, and quality.
 * Session Replay captures a video-like recording of user interactions for
 * debugging.
 *
 * @see SentryOptions
 */
@interface SentryReplayOptions : NSObject

/**
 * Sample rate for replaying sessions.
 *
 * Value between 0.0 and 1.0. Defaults to 0.0 (disabled).
 * Only sampled sessions will record replays.
 */
@property (nonatomic, assign) float sessionSampleRate;

/**
 * Sample rate for replaying sessions with errors.
 *
 * Value between 0.0 and 1.0. Defaults to 0.0 (disabled).
 * Sessions with errors are more likely to need replay for debugging.
 */
@property (nonatomic, assign) float onErrorSampleRate;

/**
 * Whether to mask all text in the replay.
 *
 * When @c YES, all text is replaced with placeholder blocks. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL maskAllText;

/**
 * Whether to mask all images in the replay.
 *
 * When @c YES, all images are replaced with placeholder blocks. Defaults to @c YES.
 */
@property (nonatomic, assign) BOOL maskAllImages;

/**
 * Video quality for replay recordings.
 *
 * Higher quality produces clearer recordings but larger files. Defaults to medium.
 */
@property (nonatomic, assign) SentryReplayQuality quality;

/**
 * View classes to mask in the replay.
 *
 * Views of these classes will have their content hidden.
 */
@property (nonatomic, copy) NSArray<Class> *maskedViewClasses;

/**
 * View classes to explicitly not mask in the replay.
 *
 * Overrides @c maskAllText and @c maskAllImages for these view classes.
 */
@property (nonatomic, copy) NSArray<Class> *unmaskedViewClasses;

/**
 * View class names to exclude from subtree traversal.
 *
 * Views with these class names and their children will not be rendered.
 */
@property (nonatomic, copy) NSSet<NSString *> *excludedViewClasses;

/**
 * View class names to include in subtree traversal.
 *
 * Overrides exclusions for these view classes.
 */
@property (nonatomic, copy) NSSet<NSString *> *includedViewClasses;

/**
 * Whether to enable the V2 view renderer.
 *
 * @warning Experimental. May change in future versions.
 */
@property (nonatomic, assign) BOOL enableViewRendererV2;

/**
 * Whether to enable fast view rendering optimizations.
 *
 * @warning Experimental. May change in future versions.
 */
@property (nonatomic, assign) BOOL enableFastViewRendering;

/**
 * Excludes a view type from being rendered in replays.
 *
 * The view and its entire subtree will not appear in the replay.
 *
 * @param viewType Fully qualified class name (e.g., "UITextField").
 */
- (void)excludeViewTypeFromSubtreeTraversal:(NSString *)viewType;

/**
 * Includes a view type in replay rendering.
 *
 * Overrides previous exclusions for this view type.
 *
 * @param viewType Fully qualified class name (e.g., "UITextField").
 */
- (void)includeViewTypeInSubtreeTraversal:(NSString *)viewType;

@end

#endif // SENTRY_OBJC_REPLAY_SUPPORTED

NS_ASSUME_NONNULL_END
