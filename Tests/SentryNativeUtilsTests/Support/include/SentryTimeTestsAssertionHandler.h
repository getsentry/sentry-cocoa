#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryTimeTestsAssertionHandler : NSAssertionHandler
+ (void)performIgnoringAssertions:(void (^)(void))block;
@end

NS_ASSUME_NONNULL_END
