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

@end

NS_ASSUME_NONNULL_END

#endif
