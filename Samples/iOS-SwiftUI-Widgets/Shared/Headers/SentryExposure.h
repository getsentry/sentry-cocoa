#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryHubInternal : NSObject

- (NSArray<NSString *> *)trimmedInstalledIntegrationNames;

@end

@interface SentrySDKInternal : NSObject

//+ (SentryHubInternal *)currentHub;

+ (NSArray<NSString *> *)trimmedInstalledIntegrationNames;

@end

NS_ASSUME_NONNULL_END
