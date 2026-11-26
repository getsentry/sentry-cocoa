#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * To easier register classes to the Objective-C runtime from Swift.
 */
@interface SentryClassRegistrator : NSObject

+ (void)registerClass:(NSString *)name;

+ (void)unregisterClass:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
