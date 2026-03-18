#import <Foundation/Foundation.h>

#import "SentryObjCSerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Approximate geographical location of the end user or device.
 *
 * Used to add geographical context to events and users. Location data is
 * typically derived from IP addresses or GPS when available.
 *
 * @see SentryUser
 */
@interface SentryGeo : NSObject <SentrySerializable, NSCopying>

/**
 * Human-readable city name.
 */
@property (nullable, atomic, copy) NSString *city;

/**
 * Two-letter country code (ISO 3166-1 alpha-2).
 *
 * Examples: "US", "GB", "DE".
 */
@property (nullable, atomic, copy) NSString *countryCode;

/**
 * Human-readable region name or code.
 *
 * May be a state, province, or administrative region.
 */
@property (nullable, atomic, copy) NSString *region;

/**
 * Compares this geographical location with another object for equality.
 *
 * @param other The object to compare with.
 * @return @c YES if the objects are equal, @c NO otherwise.
 */
- (BOOL)isEqual:(nullable id)other;

/**
 * Compares this geographical location with another location for equality.
 *
 * @param geo The geographical location to compare with.
 * @return @c YES if the locations are equal, @c NO otherwise.
 */
- (BOOL)isEqualToGeo:(SentryGeo *)geo;

/**
 * Returns a hash value for this geographical location.
 *
 * @return The hash value.
 */
- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
