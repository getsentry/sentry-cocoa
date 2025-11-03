#import <Foundation/Foundation.h>
#import <Sentry/SentryScope.h>
#import <UIKit/UIKit.h>

@class SentryOptionsInternal;

NS_ASSUME_NONNULL_BEGIN

@interface SentryBreadcrumbTracker : NSObject

+ (nullable NSDictionary *)extractDataFromView:(UIView *)view
                   withAccessibilityIdentifier:(BOOL)includeIdentifier;

@end

@interface SentryClientInternal : NSObject

@property (nonatomic) SentryOptionsInternal *options;

@end

@interface SentryHubInternal : NSObject

- (nullable SentryClientInternal *)getClient;

@end

@interface SentrySDKInternal : NSObject

+ (nullable NSArray<NSString *> *)relevantViewControllersNames;

+ (SentryHubInternal *)currentHub;

@end

NS_ASSUME_NONNULL_END
