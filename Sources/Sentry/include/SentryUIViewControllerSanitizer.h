#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An auxiliary class to extract information from UIViewController.
 */
@interface SentryUIViewControllerSanitizer : NSObject

/**
 * Retrieve the view controller class name
 *
 * @param controller A view controller to retrieve the class name.
 *
 * @return The view controller sanitized class name.
 */
+ (NSString *)sanitizeViewControllerName:(id)controller;

@end

NS_ASSUME_NONNULL_END
