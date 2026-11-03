#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SDK_V10
#    if (TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION) && SENTRY_OBJC_HAS_UIKIT
NS_ASSUME_NONNULL_BEGIN

/// Shared masking and view traversal settings for session replay and screenshot attachments.
@interface SentryObjCPrivacyOptions : NSObject

/// Masks all text content. Defaults to YES.
@property (nonatomic) BOOL maskAllText;
/// Masks non-bundled images. Defaults to YES.
@property (nonatomic) BOOL maskAllImages;
/// Custom view classes to mask, including their children.
@property (nonatomic, copy) NSArray<Class> *maskedViewClasses;
/// View classes to leave unmasked. Their children may still be masked.
@property (nonatomic, copy) NSArray<Class> *unmaskedViewClasses;
/// Patterns excluded from subtree traversal, using partial class-name matching.
@property (nonatomic, copy, readonly) NSSet<NSString *> *excludedViewClasses;
/// Class names included in subtree traversal, using exact matching.
@property (nonatomic, copy, readonly) NSSet<NSString *> *includedViewClasses;

/// Initializes privacy options with text and image masking enabled.
- (instancetype)init;
/// Excludes matching view subtrees from traversal using partial class-name matching.
- (void)excludeViewTypeFromSubtreeTraversal:(NSString *)viewType;
/// Restores traversal for the exact view class name.
- (void)includeViewTypeInSubtreeTraversal:(NSString *)viewType;

@end

NS_ASSUME_NONNULL_END
#    endif // UI platforms
#endif // SDK_V10
