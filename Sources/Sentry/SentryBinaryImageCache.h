#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BinaryImageInfo : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic) NSUInteger address;
@property (nonatomic) NSUInteger size;
@end

@interface SentryBinaryImageCache : NSObject

@property (nonatomic, readonly, class) SentryBinaryImageCache *shared;

- (void)start;

- (void)stop;

- (nullable BinaryImageInfo *)imageByAddress:(NSUInteger)address;

@end

NS_ASSUME_NONNULL_END
