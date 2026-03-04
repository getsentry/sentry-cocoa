#import <Foundation/Foundation.h>

#import "SentryObjCSerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Approximate geographical location of the end user or device.
 *
 * @see SentryUser
 */
@interface SentryGeo : NSObject <SentrySerializable, NSCopying>

/** Human readable city name. */
@property (nullable, atomic, copy) NSString *city;

/** Two-letter country code (ISO 3166-1 alpha-2). */
@property (nullable, atomic, copy) NSString *countryCode;

/** Human readable region name or code. */
@property (nullable, atomic, copy) NSString *region;

- (BOOL)isEqual:(id)other;
- (BOOL)isEqualToGeo:(SentryGeo *)geo;
- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
