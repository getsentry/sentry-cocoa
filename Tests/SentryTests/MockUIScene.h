#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))
@interface MockUIScene : UIScene

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
#endif
