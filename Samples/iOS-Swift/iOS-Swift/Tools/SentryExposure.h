#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SentryHub;

NS_ASSUME_NONNULL_BEGIN

@interface SentryBreadcrumbTracker : NSObject

+ (nullable NSDictionary *)extractDataFromView:(UIView *)view
                   withAccessibilityIdentifier:(BOOL)includeIdentifier;

@end

@interface SentrySDKInternal : NSObject

+ (nullable NSArray<NSString *> *)relevantViewControllersNames;

+ (SentryHub *)currentHub;

@end

NS_ASSUME_NONNULL_END
