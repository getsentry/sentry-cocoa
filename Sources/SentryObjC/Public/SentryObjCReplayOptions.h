#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#    import "SentryObjCReplayQuality.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#    import <SentryObjC/SentryObjCReplayQuality.h>
#endif

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

@end

NS_ASSUME_NONNULL_END
