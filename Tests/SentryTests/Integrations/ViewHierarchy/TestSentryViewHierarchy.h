#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryCrashJSONCodec.h"
#    import "SentryViewHierarchy.h"

void saveViewHierarchy(const char *path);

@interface
SentryViewHierarchy (Test)
- (int)viewHierarchyFromView:(UIView *)view intoContext:(SentryCrashJSONEncodeContext *)context;
- (BOOL)processViewHierarchy:(NSArray<UIView *> *)windows
                 addFunction:(SentryCrashJSONAddDataFunc)addJSONDataFunc
                    userData:(void *const)userData;
@end

#endif // SENTRY_HAS_UIKIT
