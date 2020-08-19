#import "SentryFileManager.h"
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Used to make eventsPath visible for testing.
 */
@interface SentryFileManager (EventsPath)

@property (nonatomic, copy) NSString *eventsPath;

@end

NS_ASSUME_NONNULL_END
