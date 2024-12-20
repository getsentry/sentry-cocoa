#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryExtraPackages : NSObject
SENTRY_NO_INIT

+ (void)addPackageName:(NSString *)name version:(NSString *)version;
+ (NSMutableSet<NSDictionary<NSString *, NSString *> *> *)getPackages;

#if TEST || TESTCI
+ (void)clear;
#endif

@end

NS_ASSUME_NONNULL_END
