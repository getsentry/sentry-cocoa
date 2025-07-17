#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryBinaryImageInfo : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, copy) NSString *UUID;
@property (nonatomic) uint64_t vmAddress;
@property (nonatomic) uint64_t address;
@property (nonatomic) uint64_t size;

@end

NS_ASSUME_NONNULL_END
