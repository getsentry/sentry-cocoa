#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
static NSString *const SENTRY_IO_OPERATION = @"IO";

@interface SentryNSDataTracker : NSObject

@property (class, readonly, nonatomic) SentryNSDataTracker *sharedInstance;

- (void)enable;

- (void)disable;

@end

NS_ASSUME_NONNULL_END
