#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySdkPackage : NSObject
SENTRY_NO_INIT

+ (nullable NSDictionary<NSString *, NSString *> *)global;

#if TEST || TESTCI
+ (void)setPackageManager:(NSUInteger)manager;
+ (void)resetPackageManager;
#endif

@end

NS_ASSUME_NONNULL_END
