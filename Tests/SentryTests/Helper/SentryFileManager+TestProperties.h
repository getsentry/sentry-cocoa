#import "SentryFileManager.h"
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Used to make properties visible for testing.
 */
@interface SentryFileManager (TestProperties)

@property (nonatomic, copy) NSString *eventsPath;

@property (nonatomic, copy) NSString *envelopesPath;

@end

NS_ASSUME_NONNULL_END
