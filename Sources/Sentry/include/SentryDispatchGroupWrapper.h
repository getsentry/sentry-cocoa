#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around DispatchGroup for testability.
 */
@interface SentryDispatchGroupWrapper : NSObject

- (intptr_t)waitWithTimeout:(dispatch_time_t)timeout;

- (void)enter;

- (void)leave;

@end

NS_ASSUME_NONNULL_END
