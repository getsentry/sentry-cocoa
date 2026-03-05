#import <UIKit/UIKit.h>

/**
 * An empty ViewController to ensure the swizzling of the SentrySDK doesn't call the initialize
 * method from a background thread. The initializer method is called before the runtime sends its
 * first message to the class, which is also the case when swizzling a class. For more information
 * checkout SentryUIViewControllerSwizzling.
 */
@interface InitializerViewController : UIViewController

@end
