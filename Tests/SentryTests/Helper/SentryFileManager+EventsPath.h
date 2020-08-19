#import <Sentry/Sentry.h>
#import "SentryFileManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Used to make eventsPath visible for testing.
 */
@interface SentryFileManager (EventsPath)

@property (nonatomic, copy) NSString *eventsPath;

@end

NS_ASSUME_NONNULL_END
