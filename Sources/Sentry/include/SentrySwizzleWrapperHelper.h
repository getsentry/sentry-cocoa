#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

@class SentryNetworkTracker;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySwizzleWrapperHelper : NSObject

+ (void)swizzle:(void (^)(SEL action, _Nullable id target, _Nullable id sender,
                    UIEvent *_Nullable event))callback;

+ (void)swizzleURLSessionTask:(SentryNetworkTracker *)networkTracker;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
