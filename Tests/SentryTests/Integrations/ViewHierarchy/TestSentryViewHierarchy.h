#import "SentryCrashJSONCodec.h"
#import "SentryDefines.h"
#import "SentryViewHierarchy.h"

#if SENTRY_HAS_UIKIT

void saveViewHierarchy(const char *path);

@interface
SentryViewHierarchy (Test)
- (int)viewHierarchyFromView:(UIView *)view intoContext:(SentryCrashJSONEncodeContext *)context;
- (BOOL)processViewHierarchy:(NSArray<UIView *> *)windows
                 addFunction:(SentryCrashJSONAddDataFunc)addJSONDataFunc
                    userData:(void *const)userData;
@end
#endif
