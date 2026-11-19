#import "SentrySwift.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if defined(DEBUG) // Test support.
@interface SentryOptions (Tests)

- (nullable instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary
                           didFailWithError:(NSError *_Nullable *_Nullable)error;

@end
#endif // defined(DEBUG)

NS_ASSUME_NONNULL_END
