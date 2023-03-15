#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryScreenshot : NSObject

/**
 * Get a screenshot of every open window in the app.
 *
 * @return An array of NSData containing a PNG image
 */
- (nullable NSArray<NSData *> *)appScreenshots;

/**
 * Save the current app screen shots in the given directory.
 * If an app has more than one screen, one image for each screen will be saved.
 *
 * @param filesDirectory The path where the images should be saved.
 */
- (void)saveScreenShots:(NSString *)filesDirectory;

- (NSArray<NSData *> *)takeScreenshots;
@end

NS_ASSUME_NONNULL_END
#endif
