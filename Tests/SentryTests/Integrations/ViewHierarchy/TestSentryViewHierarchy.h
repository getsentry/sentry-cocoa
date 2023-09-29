#import "SentryDefines.h"

#if UIKIT_LINKED

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

#endif // UIKIT_LINKED
