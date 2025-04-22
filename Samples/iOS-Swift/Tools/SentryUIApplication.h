/**
 * This header exposes a private API of the SDK for testing.
 */

NS_ASSUME_NONNULL_BEGIN

@interface SentryUIApplication : NSObject

/**
 * Use @c [SentryUIApplication relevantViewControllers] and convert the
 * result to a string array with the class name of each view controller.
 */
- (nullable NSArray<NSString *> *)relevantViewControllersNames;

@end

NS_ASSUME_NONNULL_END
