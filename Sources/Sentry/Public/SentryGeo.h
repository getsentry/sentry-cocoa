#import "SentryDefines.h"
#import "SentrySerializable.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Geo)
@interface SentryGeo : NSObject <SentrySerializable, NSCopying>

/**
 * Optional: Human readable city name.
 */
@property (atomic, copy) NSString *_Nullable city;

/**
 * Optional: Two-letter country code (ISO 3166-1 alpha-2).
 */
@property (atomic, copy) NSString *_Nullable countryCode;

/**
 * Optional: Human readable region name or code.
 */
@property (atomic, copy) NSString *_Nullable region;

- (instancetype)init;

- (BOOL)isEqual:(id _Nullable)other;

- (BOOL)isEqualToGeo:(SentryGeo *)geo;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
