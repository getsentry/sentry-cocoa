#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryCrashJSONCodec.h"

void saveViewHierarchy(const char *path);

@interface SentryViewHierarchyProviderHelper (Test)
+ (int)viewHierarchyFromView:(UIView *)view
                      intoContext:(SentryCrashJSONEncodeContext *)context
    reportAccessibilityIdentifier:(BOOL)reportAccessibilityIdentifier;
- (BOOL)processViewHierarchy:(NSArray<UIView *> *)windows
                 addFunction:(SentryCrashJSONAddDataFunc)addJSONDataFunc
                    userData:(void *const)userData;
@end

#endif // SENTRY_HAS_UIKIT
