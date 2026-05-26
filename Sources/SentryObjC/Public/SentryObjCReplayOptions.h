#import <Foundation/Foundation.h>
#import <SentryObjC/SentryObjCReplayQuality.h>

NS_ASSUME_NONNULL_BEGIN

/// Configuration options for the Session Replay feature.
@interface SentryObjCReplayOptions : NSObject

/**
 * Indicates the percentage in which the replay for the session will be created.
 * Specifying @c 0 means never, @c 1.0 means always.
 * @note The value needs to be >= 0.0 and <= 1.0. When setting a value out of range the SDK sets it
 * to the default.
 */
@property (nonatomic) float sessionSampleRate;

/**
 * Indicates the percentage in which a 30 seconds replay will be sent with error events.
 * Specifying @c 0 means never, @c 1.0 means always.
 * @note The value needs to be >= 0.0 and <= 1.0. When setting a value out of range the SDK sets it
 * to the default.
 */
@property (nonatomic) float onErrorSampleRate;

/**
 * Indicates whether session replay should redact all text in the app
 * by drawing a black rectangle over it.
 */
@property (nonatomic) BOOL maskAllText;

/**
 * Indicates whether session replay should redact all non-bundled images
 * in the app by drawing a black rectangle over it.
 */
@property (nonatomic) BOOL maskAllImages;

/**
 * Indicates the quality of the replay.
 * The higher the quality, the higher the CPU and bandwidth usage.
 */
@property (nonatomic) SentryObjCReplayQuality quality;

/**
 * Enables the up to 5x faster new view renderer used by the Session Replay integration.
 *
 * Enabling this flag will reduce the amount of time it takes to render each frame of the session
 * replay on the main thread, therefore reducing interruptions and visual lag.
 */
@property (nonatomic) BOOL enableViewRendererV2;

/**
 * Enables up to 5x faster but incomplete view rendering used by the Session Replay integration.
 *
 * This flag controls the way the view hierarchy is drawn into a graphics context for the session
 * replay. Enabling this flag will switch to render the underlying @c CALayer instead.
 *
 * @note This flag can only be used together with @c enableViewRendererV2.
 * @warning Rendering the view hierarchy using @c CALayer can lead to rendering issues with custom
 * views.
 */
@property (nonatomic) BOOL enableFastViewRendering;

/**
 * A list of custom @c UIView subclasses that need to be masked during session replay.
 * By default Sentry already masks text and image elements from UIKit.
 * Every child of a view that is redacted will also be redacted.
 */
@property (nonatomic, copy) NSArray<Class> *maskedViewClasses;

/**
 * A list of custom @c UIView subclasses to be ignored during the masking step of session replay.
 * The views of given classes will not be redacted but their children may be.
 * This property has precedence over @c maskedViewClasses.
 */
@property (nonatomic, copy) NSArray<Class> *unmaskedViewClasses;

/**
 * Whether to capture request and response bodies for allowed URLs.
 *
 * When @c YES (default), bodies will be captured and parsed (JSON bodies are
 * parsed for structured display in the Sentry UI).
 * When @c NO, only headers and metadata will be captured for allowed URLs.
 */
@property (nonatomic) BOOL networkCaptureBodies;

/**
 * Request headers to capture for allowed URLs during session replay.
 * Specifies which HTTP request headers should be captured and included in session replay
 * network details. Header matching is case-insensitive.
 */
@property (nonatomic, copy) NSArray<NSString *> *networkRequestHeaders;

/**
 * Response headers to capture for allowed URLs during session replay.
 * Specifies which HTTP response headers should be captured and included in session replay
 * network details. Header matching is case-insensitive.
 */
@property (nonatomic, copy) NSArray<NSString *> *networkResponseHeaders;

/// Initializes session replay options with default values.
- (instancetype)init;

/**
 * Adds a view type pattern to the excluded set, preventing matching views' subtrees from being
 * traversed during session replay redaction.
 *
 * Matching uses partial string containment: if a view's class name contains this string,
 * the subtree will be ignored.
 *
 * @param viewType The view type identifier pattern to exclude from subtree traversal.
 */
- (void)excludeViewTypeFromSubtreeTraversal:(NSString *)viewType;

/**
 * Adds a view type to the included set, allowing its subtree to be traversed even if it would
 * otherwise be excluded by default or via @c excludeViewTypeFromSubtreeTraversal:.
 *
 * Matching uses exact string matching.
 *
 * @param viewType The view type identifier to include in subtree traversal.
 */
- (void)includeViewTypeInSubtreeTraversal:(NSString *)viewType;

@end

NS_ASSUME_NONNULL_END
