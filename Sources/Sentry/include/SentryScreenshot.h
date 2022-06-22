#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryScreenshot : NSObject

/**
 * Get a screenshot of every open window in the app.
 *
 * @return An array of NSData containing a PNG image
 */
- (nullable NSArray<NSData *> *)appScreenshots;

- (void)saveScreenShots:(NSString*)path;
@end

NS_ASSUME_NONNULL_END
#endif
