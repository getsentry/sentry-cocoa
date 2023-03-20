#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(User)
@interface SentryUser : NSObject <SentrySerializable, NSCopying>

/**
 * Optional: Id of the user
 */
@property (atomic, copy) NSString *_Nullable userId;

/**
 * Optional: Email of the user
 */
@property (atomic, copy) NSString *_Nullable email;

/**
 * Optional: Username
 */
@property (atomic, copy) NSString *_Nullable username;

/**
 * Optional: IP Address
 */
@property (atomic, copy) NSString *_Nullable ipAddress;

/**
 * The user segment, for apps that divide users in user segments.
 */
@property (atomic, copy) NSString *_Nullable segment;

/**
 * Optional: Additional data
 */
@property (atomic, strong) NSDictionary<NSString *, id> *_Nullable data;

/**
 * Optional: Additional serialization data
 */
@property (atomic, strong) NSDictionary<NSString *, id> *_Nullable unknown;

/**
 * Initializes a SentryUser from a JSON object.
 * @param jsonObject The jsonObject containing the user.
 * @return The SentryUser or nil if the JSONObject contains an error.
 */
- (nullable instancetype)initWithJSONObject:(NSDictionary *)jsonObject;

/**
 * Initializes a SentryUser with the id
 * @param userId NSString
 * @return SentryUser
 */
- (instancetype)initWithUserId:(NSString *)userId;

- (instancetype)init;

- (BOOL)isEqual:(id _Nullable)other;

- (BOOL)isEqualToUser:(SentryUser *)user;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
