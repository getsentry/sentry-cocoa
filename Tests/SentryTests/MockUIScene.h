// These mocks must be in ObjC because their init methods use `return self`
// to skip calling UIScene's designated initializer
// (initWithSession:connectionOptions:), which requires a UISceneSession and
// triggers an NSApplication crash on macCatalyst 26.0.
// Swift enforces calling super.init, making this impossible to express safely.

#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))
@interface MockUIScene : UIScene

- (instancetype)init;

@end

API_AVAILABLE(ios(13.0))
@interface MockUIWindowScene : UIWindowScene

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
#endif
