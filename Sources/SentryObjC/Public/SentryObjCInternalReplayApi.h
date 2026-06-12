#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_REPLAY_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

/// Replay APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalReplayApi : NSObject

/// Captures a replay.
/// @return @c YES if capture succeeded.
- (BOOL)capture;

/// The current replay ID, or @c nil if no replay session is active.
@property (nonatomic, readonly, nullable, copy) NSString *replayId;

/// Adds classes whose views should be ignored during replay recording.
- (void)addIgnoreClasses:(NSArray<Class> *)classes;

/// Adds classes whose views should be redacted during replay recording.
- (void)addRedactClasses:(NSArray<Class> *)classes;

/// Sets the container class used to determine which views to ignore.
- (void)setIgnoreContainerClass:(Class)containerClass;

/// Sets the container class used to determine which views to redact.
- (void)setRedactContainerClass:(Class)containerClass;

/// Sets custom tags on the replay session.
- (void)setTags:(NSDictionary<NSString *, id> *)tags;

@end

NS_ASSUME_NONNULL_END

#endif
