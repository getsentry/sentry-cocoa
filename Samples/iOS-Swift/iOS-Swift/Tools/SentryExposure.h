#import <Foundation/Foundation.h>
#import <Sentry/SentryScope.h>
#import <UIKit/UIKit.h>

@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientInternal : NSObject

@property (nonatomic) SentryOptions *options;

@end

@interface SentryHubInternal : NSObject

- (nullable SentryClientInternal *)getClient;

- (NSArray<NSString *> *)trimmedInstalledIntegrationNames;

@end

@interface SentrySDKInternal : NSObject

+ (nullable NSArray<NSString *> *)relevantViewControllersNames;

+ (SentryHubInternal *)currentHub;

+ (NSArray<NSString *> *)trimmedInstalledIntegrationNames;

@end

NS_ASSUME_NONNULL_END
