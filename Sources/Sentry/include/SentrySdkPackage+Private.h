#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentrySdkPackage.h>
#else
#    import "SentrySdkPackage.h"
#endif

@interface SentrySdkPackage ()

+ (nullable instancetype)getSentrySDKPackage:(NSUInteger)packageManger;

@end
