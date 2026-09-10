#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_REPLAY_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

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

/// Flushes buffered replay data or starts a new replay session if Replay is inactive.
- (void)flush;

/// Stops the current replay.
- (void)stop;

/// Captures a replay event. Returns @c YES if the replay was captured.
- (BOOL)capture;

#    if SDK_V10
/// The active integration's replay ID, available in both session and buffer modes.
#    else
/// The current replay ID, or @c nil if no replay is active.
#    endif // SDK_V10
@property (nonatomic, readonly, nullable) NSString *replayId;

#    if SDK_V10
/// Whether the active replay is in buffer mode.
///
/// Returns @c NO when no replay is active.
@property (nonatomic, readonly) BOOL isBuffering;
#    endif // SDK_V10

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

@end

NS_ASSUME_NONNULL_END

#endif
