#import "SentryDefines.h"

#if UIKIT_LINKED

#    import "SentryObjCRuntimeWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions, SentryDispatchQueueWrapper, SentrySubClassFinder, SentryNSProcessInfoWrapper;

/**
 * Class is responsible to swizzle UI key methods
 * so Sentry can track UI performance.
 */
@interface SentryUIViewControllerSwizzling : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
                  dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
             objcRuntimeWrapper:(id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper
                 subClassFinder:(SentrySubClassFinder *)subClassFinder
             processInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper;

- (void)start;

@end

NS_ASSUME_NONNULL_END

#endif // UIKIT_LINKED
