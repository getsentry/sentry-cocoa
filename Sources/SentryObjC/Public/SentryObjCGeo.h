#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCGeo : NSObject

@property (nonatomic, copy, nullable) NSString *city;
@property (nonatomic, copy, nullable) NSString *countryCode;
@property (nonatomic, copy, nullable) NSString *region;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
