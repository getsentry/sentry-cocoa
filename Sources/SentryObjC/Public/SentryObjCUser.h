#import <Foundation/Foundation.h>

@class SentryObjCGeo;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCUser : NSObject

@property (nonatomic, copy, nullable) NSString *userId;
@property (nonatomic, copy, nullable) NSString *email;
@property (nonatomic, copy, nullable) NSString *username;
@property (nonatomic, copy, nullable) NSString *ipAddress;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, strong, nullable) SentryObjCGeo *geo;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *data;

- (instancetype)init;
- (instancetype)initWithUserId:(NSString *)userId;

@end

NS_ASSUME_NONNULL_END
