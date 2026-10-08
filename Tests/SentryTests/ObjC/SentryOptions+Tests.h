#import "SentrySwift.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_TEST || SENTRY_TEST_CI
@interface SentryOptions (Tests)

- (nullable instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary
                           didFailWithError:(NSError *_Nullable *_Nullable)error;

@end
#endif // SENTRY_TEST || SENTRY_TEST_CI

NS_ASSUME_NONNULL_END
