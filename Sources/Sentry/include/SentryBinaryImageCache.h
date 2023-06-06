#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BinaryImageInfo : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic) uint64_t address;
@property (nonatomic) uint64_t size;
@end

@interface SentryBinaryImageCache : NSObject

@property (nonatomic, readonly, class) SentryBinaryImageCache *shared;

- (void)start;

- (void)stop;

- (nullable BinaryImageInfo *)imageByAddress:(const uint64_t)address;

@end

NS_ASSUME_NONNULL_END
