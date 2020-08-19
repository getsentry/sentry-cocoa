#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryId : NSObject

/**
 * Creates a SentryId with a random SentryId.
 */
- (instancetype)init;

/**
 * Creates a SentryId with the given uuid.
 */
- (instancetype)initWithUUID:(NSUUID *)uuid;

/**
 * Creates a SentryId from a string such as such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F".
 *
 * @return SentryId.empty for invalid strings.
 */
- (instancetype)initWithUUIDString:(NSString *)string;

/**
 * Returns a string description of the SentryId, such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
 */
@property (readonly, copy) NSString *sentryIdString;

/**
 * A SentryId with an empty UUID "00000000-0000-0000-0000-000000000000".
 */
@property (class, nonatomic, readonly, strong) SentryId *empty;

@end

NS_ASSUME_NONNULL_END
