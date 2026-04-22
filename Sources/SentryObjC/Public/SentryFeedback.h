#import <Foundation/Foundation.h>

#import "SentryFeedbackSource.h"

@class SentryAttachment;
@class SentryId;

NS_ASSUME_NONNULL_BEGIN

// SentryFeedback is defined in Swift without an @objc(Name) override, so Swift emits
// its ObjC metadata under a mangled runtime name. Pure-ObjC consumers (no -fmodules)
// would otherwise emit a reference to _OBJC_CLASS_$_SentryFeedback at link time, which
// nothing exports. The @compatibility_alias rewrites the public spelling to the
// mangled class at compile time in every consumer TU, so the linker ends up resolving
// _OBJC_CLASS_$__TtC..._SentryFeedback — which Sentry.framework does export.
//
// SPM compiles the Swift sources under the module name "SentrySwift"; Xcode compiles
// them under "Sentry". The mangled prefix differs accordingly.
#if SWIFT_PACKAGE
@class _TtC11SentrySwift14SentryFeedback;
@compatibility_alias SentryFeedback _TtC11SentrySwift14SentryFeedback;
#else
@class _TtC6Sentry14SentryFeedback;
@compatibility_alias SentryFeedback _TtC6Sentry14SentryFeedback;
#endif

/**
 * User feedback submission.
 */
@interface SentryFeedback : NSObject

@property (nonatomic, readonly, strong) SentryId *eventId;

- (instancetype)initWithMessage:(NSString *)message
                           name:(nullable NSString *)name
                          email:(nullable NSString *)email
                         source:(SentryFeedbackSource)source
              associatedEventId:(nullable SentryId *)associatedEventId
                    attachments:(nullable NSArray<SentryAttachment *> *)attachments;

@end

NS_ASSUME_NONNULL_END
