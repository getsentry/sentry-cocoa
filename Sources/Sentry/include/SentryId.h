#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDefines.h>
#import <Sentry/SentrySerializable.h>
#else
#import "SentryDefines.h"
#import "SentrySerializable.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryId : NSObject
SENTRY_NO_INIT

/**
 * SentryId in the valid format or a String UUID.
 * A SentryId string representation is a UUID without dashes.
*/
- (instancetype)initWithString:(NSString *)sentryIdString NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
