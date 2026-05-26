#import <Foundation/Foundation.h>

@class SentryObjCMechanism;
@class SentryObjCStacktrace;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCException : NSObject

@property (nonatomic, copy, nullable) NSString *value;
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic, strong, nullable) SentryObjCMechanism *mechanism;
@property (nonatomic, copy, nullable) NSString *module;
@property (nonatomic, copy, nullable) NSNumber *threadId;
@property (nonatomic, strong, nullable) SentryObjCStacktrace *stacktrace;

- (instancetype)initWithValue:(nullable NSString *)value type:(nullable NSString *)type;

@end

NS_ASSUME_NONNULL_END
