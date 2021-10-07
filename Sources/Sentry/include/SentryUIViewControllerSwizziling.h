#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

@class SentryOptions, SentryDispatchQueueWrapper;

/**
 * Class is responsible to swizzle UI key methods
 * so Sentry can track UI performance.
 */
@interface SentryUIViewControllerSwizziling : NSObject

+ (void)startWithOptions:(SentryOptions *)options
           dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue;

@end

#endif

NS_ASSUME_NONNULL_END
