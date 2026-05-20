#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Platform-specific error context attached to an exception mechanism.
@interface SentryCompatMechanismContext : NSObject

- (instancetype)init;

@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *signal;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *machException;

@end

NS_ASSUME_NONNULL_END
