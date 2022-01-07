#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryFormatter : NSObject

+ (NSString *)bytesCountDescription:(NSUInteger)bytes;

@end

NS_ASSUME_NONNULL_END
