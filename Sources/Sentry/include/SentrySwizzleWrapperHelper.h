#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySwizzleWrapperHelper : NSObject

+ (void)swizzle:(void (^)(SEL action, _Nullable id target, _Nullable id sender,
                    UIEvent *_Nullable event))callback;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
