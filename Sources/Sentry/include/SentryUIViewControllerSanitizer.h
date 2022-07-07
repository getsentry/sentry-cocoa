#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * An auxiliary class to extract information from UIViewController.
 */
@interface SentryUIViewControllerSanitizer : NSObject

/**
 * Retrieve the view controller class name
 * and remove unwanted characters from it.
 *
 * The default description of a object
 * is "<MODULE.CLASSNAME: ADDRESS>"
 * This method returns only MODULE.CLASSNAME
 *
 * @param controller A view controller to retrieve the class name.
 *
 * @return The view controller sanitized class name.
 */
+ (NSString *)sanitizeViewControllerName:(id)controller;

#if SENTRY_HAS_UIKIT
/**
 * Fetch useful information about a UIViewController like its classname,
 * title, presentation mode, and mode.
 * */
+ (NSDictionary *)fetchInfoAboutViewController:(UIViewController *)controller;
#endif

@end

NS_ASSUME_NONNULL_END
