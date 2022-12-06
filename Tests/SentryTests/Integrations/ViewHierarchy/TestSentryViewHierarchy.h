#import "SentryViewHierarchy.h"
#import "SentryDefines.h"
#import "SentryCrashJSONCodec.h"

#if SENTRY_HAS_UIKIT
@interface SentryViewHierarchy (test)
- (int)viewHierarchyFromView:(UIView *)view intoContext:(SentryCrashJSONEncodeContext *)context;
- (BOOL)processViewHierarchy:(NSArray<UIView *> *)windows
                 addFunction:(SentryCrashJSONAddDataFunc)addJSONDataFunc
                    userData:(void *const)userData;
@end
#endif
