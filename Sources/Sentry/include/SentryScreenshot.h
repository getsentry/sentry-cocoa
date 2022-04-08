#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryScreenshot : NSObject

/**
 * Get a screenshot of every open window in the app.
 *
 * @return An array of NSData containing a PNG image
 */
- (NSArray<NSData *> *)appScreenshots;

@end

NS_ASSUME_NONNULL_END
