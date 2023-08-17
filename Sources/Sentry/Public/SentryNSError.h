#import "SentryDefines.h"
#import "SentrySerializable.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Sentry representation of an @c NSError to send to Sentry.
 */
@interface SentryNSError : NSObject <SentrySerializable>
SENTRY_NO_INIT

- (instancetype)initWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
