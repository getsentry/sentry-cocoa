#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Approximate geographic location of the end user or device.
@interface SOCSentryGeo : NSObject

- (instancetype)init;

@property (nonatomic, copy, nullable) NSString *city;
@property (nonatomic, copy, nullable) NSString *countryCode;
@property (nonatomic, copy, nullable) NSString *region;

- (BOOL)isEqual:(nullable id)object;
@property (nonatomic, readonly) NSUInteger hash;

@end

NS_ASSUME_NONNULL_END
