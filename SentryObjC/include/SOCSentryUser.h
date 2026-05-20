#import <Foundation/Foundation.h>

@class SOCSentryGeo;

NS_ASSUME_NONNULL_BEGIN

/// User identification attached to events.
@interface SOCSentryUser : NSObject

- (instancetype)init;
- (instancetype)initWithUserId:(NSString *)userId;

@property (nonatomic, copy, nullable) NSString *userId;
@property (nonatomic, copy, nullable) NSString *email;
@property (nonatomic, copy, nullable) NSString *username;
@property (nonatomic, copy, nullable) NSString *ipAddress;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, strong, nullable) SOCSentryGeo *geo;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *data;

- (BOOL)isEqual:(nullable id)object;
@property (nonatomic, readonly) NSUInteger hash;

@end

NS_ASSUME_NONNULL_END
