#import <Foundation/Foundation.h>

@class SentryObjCGeo;

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the user associated with an event.
 */
@interface SentryObjCUser : NSObject

/// Optional: Id of the user.
@property (nonatomic, copy, nullable) NSString *userId;

/// Optional: Email of the user.
@property (nonatomic, copy, nullable) NSString *email;

/// Optional: Username.
@property (nonatomic, copy, nullable) NSString *username;

/// Optional: IP Address.
@property (nonatomic, copy, nullable) NSString *ipAddress;

/// Optional: Human readable name.
@property (nonatomic, copy, nullable) NSString *name;

/// Optional: Geo location of user.
@property (nonatomic, strong, nullable) SentryObjCGeo *geo;

/// Optional: Additional data.
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *data;

- (instancetype)init;

/**
 * Initializes a @c SentryObjCUser with the id.
 * @param userId The user's identifier.
 */
- (instancetype)initWithUserId:(NSString *)userId;

@end

NS_ASSUME_NONNULL_END
