#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySubClassFinder : NSObject

/**
 * Returns an array of subclasses of the parentClass.  You shouldn't call this on the main thread as
 * this uses objc_getClassList internally, which can take up to 60 ms to complete.
 */
+ (NSArray<Class> *)classGetSubclasses:(Class)parentClass;

@end

NS_ASSUME_NONNULL_END
