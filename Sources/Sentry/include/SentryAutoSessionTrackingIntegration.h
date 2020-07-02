#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Automatically tracks session start and end.
 */
@interface SentryAutoSessionTrackingIntegration : NSObject

- (void)stop;

@end

NS_ASSUME_NONNULL_END
