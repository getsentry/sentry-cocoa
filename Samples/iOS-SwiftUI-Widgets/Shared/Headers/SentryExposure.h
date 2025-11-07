#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDKInternal : NSObject

+ (NSArray<NSString *> *)trimmedInstalledIntegrationNames;

@end

NS_ASSUME_NONNULL_END
