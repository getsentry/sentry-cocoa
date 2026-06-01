#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a Sentry identifier. A Sentry ID is a UUID stored as a 32-character hexadecimal string
 * without dashes.
 */
@interface SentryObjCId : NSObject

/**
 * Returns a 32 lowercase character hexadecimal string description of the @c SentryObjCId, such as
 * "12c2d058d58442709aa2eca08bf20986".
 */
@property (nonatomic, readonly, copy) NSString *sentryIdString;

/// A @c SentryObjCId with an empty UUID "00000000000000000000000000000000".
@property (nonatomic, class, readonly, strong) SentryObjCId *empty;

/// Creates a @c SentryObjCId with a random UUID.
- (instancetype)init;

/// Creates a @c SentryObjCId with the given UUID.
- (instancetype)initWithUuid:(NSUUID *)uuid;

/**
 * Creates a @c SentryObjCId from a 32 character hexadecimal string without dashes such as
 * "12c2d058d58442709aa2eca08bf20986" or a 36 character hexadecimal string such as
 * "12c2d058-d584-4270-9aa2-eca08bf20986".
 * @return @c SentryObjCId.empty for invalid strings.
 */
- (instancetype)initWithUUIDString:(NSString *)uuidString;

@end

NS_ASSUME_NONNULL_END
