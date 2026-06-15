#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))
@interface MockUIScene : UIScene

- (instancetype)init;

@end

API_AVAILABLE(ios(13.0))
@interface MockUISceneSession : UISceneSession

- (instancetype)initWithRole:(UISceneSessionRole)role;

@end

API_AVAILABLE(ios(13.0))
@interface MockUIWindowScene : UIWindowScene

- (instancetype)initWithSessionRole:(UISceneSessionRole)role;

@end

NS_ASSUME_NONNULL_END
#endif
