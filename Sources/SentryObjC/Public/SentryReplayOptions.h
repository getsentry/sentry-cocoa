#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

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
 * A list of URL patterns to capture request and response details for during session replay.
 *
 * When non-empty, network requests with URLs matching any of these patterns will have their
 * headers and bodies captured for session replay.
 *
 * Supports both @c NSString (substring matching) and @c NSRegularExpression (regex matching).
 *
 * @note Requires @c options.experimental.enableReplayNetworkDetailsCapturing to be @c YES.
 * @note Default is an empty array (network detail capture disabled).
 */
@property (nonatomic, copy) NSArray *networkDetailAllowUrls;

/**
 * A list of URL patterns to exclude from network detail capture during session replay.
 *
 * URLs matching any pattern in this array will NOT have their headers and bodies captured,
 * even if they match patterns in @c networkDetailAllowUrls.
 *
 * Supports both @c NSString (substring matching) and @c NSRegularExpression (regex matching).
 *
 * @note Requires @c options.experimental.enableReplayNetworkDetailsCapturing to be @c YES.
 * @note Default is an empty array (no URLs explicitly denied).
 */
@property (nonatomic, copy) NSArray *networkDetailDenyUrls;

/**
 * Whether to capture request and response bodies for allowed URLs.
 *
 * When @c YES (default), bodies will be captured and parsed for allowed URLs.
 * When @c NO, only headers and metadata will be captured.
 *
 * @note This setting only applies when @c networkDetailAllowUrls is non-empty.
 * @note Bodies are automatically truncated to 150KB.
 * @note Requires @c options.experimental.enableReplayNetworkDetailsCapturing to be @c YES.
 */
@property (nonatomic, assign) BOOL networkCaptureBodies;

/**
 * Request headers to capture for allowed URLs during session replay.
 *
 * Default (always included): @c Content-Type, @c Content-Length, @c Accept.
 * Header matching is case-insensitive.
 *
 * @note Requires @c options.experimental.enableReplayNetworkDetailsCapturing to be @c YES.
 */
@property (nonatomic, copy) NSArray<NSString *> *networkRequestHeaders;

/**
 * Response headers to capture for allowed URLs during session replay.
 *
 * Default (always included): @c Content-Type, @c Content-Length, @c Accept.
 * Header matching is case-insensitive.
 *
 * @note Requires @c options.experimental.enableReplayNetworkDetailsCapturing to be @c YES.
 */
@property (nonatomic, copy) NSArray<NSString *> *networkResponseHeaders;

/**
 * Determines if network detail capture is enabled for a given URL.
 *
 * @param urlString The URL string to check.
 * @return @c YES if network details should be captured for this URL, @c NO otherwise.
 */
- (BOOL)isNetworkDetailCaptureEnabledFor:(NSString *)urlString;

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
