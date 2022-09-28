
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryDescriptor <NSObject>

- (NSString *)getDescription:(id)object;

@end

@interface SentryDescriptor : NSObject <SentryDescriptor>

@end

NS_ASSUME_NONNULL_END
