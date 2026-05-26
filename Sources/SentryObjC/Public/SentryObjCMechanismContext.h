#import <Foundation/Foundation.h>

@class SentryObjCNSError;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCMechanismContext : NSObject

@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *signal;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *machException;
@property (nonatomic, strong, nullable) SentryObjCNSError *error;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
