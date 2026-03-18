#import <Foundation/Foundation.h>

#import "SentryObjCSerializable.h"

@class SentryGeo;

NS_ASSUME_NONNULL_BEGIN

/**
 * User information attached to events.
 *
 * Use this to identify and provide context about the user who experienced an issue.
 * Setting user information helps correlate events with specific users in Sentry.
 *
 * @see SentryScope
 */
@interface SentryUser : NSObject <SentrySerializable, NSCopying>

/**
 * Unique identifier for the user.
 */
@property (atomic, copy) NSString *userId;

/**
 * Email address of the user.
 *
 * @note Only sent when @c sendDefaultPii is @c YES.
 */
@property (atomic, copy) NSString *email;

/**
 * Username of the user.
 *
 * @note Only sent when @c sendDefaultPii is @c YES.
 */
@property (atomic, copy) NSString *username;

/**
 * IP address of the user.
 *
 * @note Only sent when @c sendDefaultPii is @c YES. If not set, Sentry
 * will use the IP address from the HTTP request.
 */
@property (atomic, copy) NSString *ipAddress;

/**
 * Display name of the user.
 */
@property (atomic, copy) NSString *name;

/**
 * Geographic location information for the user.
 */
@property (nullable, nonatomic, strong) SentryGeo *geo;

/**
 * Additional arbitrary data associated with the user.
 */
@property (atomic, strong) NSDictionary<NSString *, id> *data;

/**
 * Creates a user with the specified user ID.
 *
 * @param userId The unique identifier for the user.
 * @return A new user instance.
 */
- (instancetype)initWithUserId:(NSString *)userId;

/**
 * Creates a user with default values.
 *
 * @return A new user instance.
 */
- (instancetype)init;

/**
 * Compares this user with another object for equality.
 *
 * @param other The object to compare with.
 * @return @c YES if the objects are equal, @c NO otherwise.
 */
- (BOOL)isEqual:(nullable id)other;

/**
 * Compares this user with another user for equality.
 *
 * @param user The user to compare with.
 * @return @c YES if the users are equal, @c NO otherwise.
 */
- (BOOL)isEqualToUser:(SentryUser *)user;

/**
 * Returns a hash value for this user.
 *
 * @return The hash value.
 */
- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
