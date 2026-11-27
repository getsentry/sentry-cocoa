#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_REPLAY_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@class SentryObjCId;
@class UIImage;
@class UIView;

/// Supplies the frames of a session replay in place of the SDK's own screen capture.
///
/// For hybrid SDKs that render outside UIKit's view hierarchy, such as game engines.
@protocol SentryObjCReplayScreenshotProvider <NSObject>

/// Called on the main thread for each frame the replay records.
///
/// Call @c onComplete exactly once, on any thread, with an image of @c view's size in points.
/// The replay captures no further frame until it's called.
- (void)imageWithView:(UIView *)view onComplete:(void (^)(UIImage *image))onComplete;

@end

/// Session replay APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalReplayApi : NSObject
SENTRY_NO_INIT

/// Starts a new replay session if Replay is inactive.
- (void)start;

/// Starts Replay in buffer mode if Replay is inactive.
- (void)startBuffering;

/// Pauses the current replay.
- (void)pause;

/// Resumes a replay paused with @c pause.
- (void)resume;

/// Stops recording touch positions until @c resumeTouchTracking is called.
- (void)pauseTouchTracking;

/// Resumes recording touch positions paused with @c pauseTouchTracking.
- (void)resumeTouchTracking;

/// Flushes buffered replay data or starts a new replay session if Replay is inactive.
- (void)flush;

/// Stops the current replay.
- (void)stop;

/// Sets the provider of the replay's frames, for the current replay and every replay started
/// afterwards, until the SDK is closed. Call it again after each start of the SDK.
///
/// May be called from any thread; it takes effect on the main thread. Does nothing when Session
/// Replay isn't installed.
- (void)setScreenshotProvider:(id<SentryObjCReplayScreenshotProvider>)provider;

/// Captures a replay event. Returns @c YES if the replay was captured.
- (BOOL)capture;

/// The current replay ID, or @c nil if no replay is active.
@property (nonatomic, readonly, nullable) NSString *replayId;

/// Adds classes to the replay ignore list.
- (void)addIgnoreClasses:(NSArray<Class> *)classes;

/// Adds classes to the replay redact list.
- (void)addRedactClasses:(NSArray<Class> *)classes;

/// Sets the container class whose subviews are ignored during replay.
- (void)setIgnoreContainerClass:(Class)containerClass;

/// Sets the container class whose subviews are redacted during replay.
- (void)setRedactContainerClass:(Class)containerClass;

/// Sets tags on the current replay session.
- (void)setTags:(NSDictionary<NSString *, id> *)tags;

/// Registers a trace ID with the current replay segment.
- (void)registerTraceId:(SentryObjCId *)traceId;

@end

NS_ASSUME_NONNULL_END

#endif
