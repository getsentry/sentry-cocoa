#import <Foundation/Foundation.h>

#import "SentryLevel.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Breadcrumb representing a discrete event that occurred before a Sentry event.
 *
 * Breadcrumbs are used to create a trail of events leading up to an error or exception.
 * They provide context about what the user was doing when the error occurred.
 *
 * @see SentryScope
 */
@interface SentryBreadcrumb : NSObject <SentrySerializable>

/**
 * Severity level of this breadcrumb.
 */
@property (nonatomic) SentryLevel level;

/**
 * Category of this breadcrumb.
 *
 * Common categories include "navigation", "http", "user", "console", etc.
 */
@property (nonatomic, copy) NSString *category;

/**
 * Timestamp when this breadcrumb was created.
 */
@property (nonatomic, strong, nullable) NSDate *timestamp;

/**
 * Type of breadcrumb.
 *
 * Examples: "default", "http", "navigation", "error". The type is used
 * to determine the breadcrumb icon in the Sentry UI.
 */
@property (nonatomic, copy, nullable) NSString *type;

/**
 * Human-readable message describing this breadcrumb.
 */
@property (nonatomic, copy, nullable) NSString *message;

/**
 * Origin identifying the source of this breadcrumb.
 *
 * Hybrid SDKs use this to distinguish native breadcrumbs from those
 * created by JavaScript, Flutter, or other layers.
 */
@property (nonatomic, copy, nullable) NSString *origin;

/**
 * Arbitrary additional data associated with this breadcrumb.
 *
 * This data is displayed in the Sentry UI alongside the breadcrumb.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *data;

/**
 * Creates a breadcrumb with the specified level and category.
 *
 * @param level Severity level for this breadcrumb.
 * @param category Category string for this breadcrumb.
 * @return A new breadcrumb instance.
 */
- (instancetype)initWithLevel:(SentryLevel)level category:(NSString *)category;

/**
 * Creates a breadcrumb with default values.
 *
 * @return A new breadcrumb instance.
 */
- (instancetype)init;

/**
 * Serializes the breadcrumb to a dictionary.
 *
 * @return Dictionary representation of the breadcrumb.
 */
- (NSDictionary<NSString *, id> *)serialize;

/**
 * Compares this breadcrumb with another object for equality.
 *
 * @param other The object to compare with.
 * @return @c YES if the objects are equal, @c NO otherwise.
 */
- (BOOL)isEqual:(nullable id)other;

/**
 * Compares this breadcrumb with another breadcrumb for equality.
 *
 * @param breadcrumb The breadcrumb to compare with.
 * @return @c YES if the breadcrumbs are equal, @c NO otherwise.
 */
- (BOOL)isEqualToBreadcrumb:(SentryBreadcrumb *)breadcrumb;

/**
 * Returns a hash value for this breadcrumb.
 *
 * @return The hash value.
 */
- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
