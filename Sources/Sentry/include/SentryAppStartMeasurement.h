#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryAppStartMeasurement : NSObject
SENTRY_NO_INIT

- (instancetype)initWithType:(NSString *)type duration:(NSTimeInterval)duration;

@property (readonly, nonatomic, copy) NSString *type;

@property (readonly, nonatomic, assign) NSTimeInterval duration;

@end

NS_ASSUME_NONNULL_END
