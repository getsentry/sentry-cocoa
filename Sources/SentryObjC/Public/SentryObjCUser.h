#import <Foundation/Foundation.h>

#import "SentryObjCSerializable.h"

@class SentryGeo;

NS_ASSUME_NONNULL_BEGIN

/**
 * User information attached to events.
 *
 * @see SentryScope
 */
@interface SentryUser : NSObject <SentrySerializable, NSCopying>

@property (atomic, copy) NSString *userId;
@property (atomic, copy) NSString *email;
@property (atomic, copy) NSString *username;
@property (atomic, copy) NSString *ipAddress;
@property (atomic, copy) NSString *name;
@property (nullable, nonatomic, strong) SentryGeo *geo;
@property (atomic, strong) NSDictionary<NSString *, id> *data;

- (instancetype)initWithUserId:(NSString *)userId;
- (instancetype)init;
- (BOOL)isEqual:(id)other;
- (BOOL)isEqualToUser:(SentryUser *)user;
- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
