#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryViewHierarchy : SENTRY_BASE_OBJECT

- (nullable NSData *)fetchViewHierarchy;

/**
 * Save the current app view hierarchy in the given file path.
 *
 * @param filePath The full path where the view hierarchy should be saved.
 */
- (BOOL)saveViewHierarchy:(NSString *)filePath;
@end

NS_ASSUME_NONNULL_END
#endif
