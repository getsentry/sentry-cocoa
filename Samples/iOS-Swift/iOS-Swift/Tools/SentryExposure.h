#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SentryBreadcrumbTracker : NSObject

+ (NSDictionary *)extractDataFromView:(UIView *)view
          withAccessibilityIdentifier:(BOOL)includeIdentifier;

@end
