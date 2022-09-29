
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryDescriptor <NSObject>

- (NSString *)getDescription:(id)object;

@end

@interface SentryDescriptor : NSObject <SentryDescriptor>

@property (nonatomic, class, readonly) SentryDescriptor *shared;

@end

NS_ASSUME_NONNULL_END
