#import "SentryDefines.h"
@import _SentryPrivate;

#if SENTRY_HAS_UIKIT
NS_ASSUME_NONNULL_BEGIN

// The implementation restores the Swift-defined date-provider protocol.
@interface TestDelayedWrapper : SentryDelayedFramesTracker
- (instancetype)initWithKeepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration
                                     dateProvider:(id)dateProvider; // OK: Swift protocol bridge.
@end

NS_ASSUME_NONNULL_END
#endif
