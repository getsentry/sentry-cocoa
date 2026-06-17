#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientInternal : NSObject

- (NSObject *)getOptions;

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
