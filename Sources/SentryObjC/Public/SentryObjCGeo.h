#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Approximate geographical location of the end user or device.
@interface SentryObjCGeo : NSObject

/// Optional: Human readable city name.
@property (nonatomic, copy, nullable) NSString *city;

/// Optional: Two-letter country code (ISO 3166-1 alpha-2).
@property (nonatomic, copy, nullable) NSString *countryCode;

/// Optional: Human readable region name or code.
@property (nonatomic, copy, nullable) NSString *region;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
