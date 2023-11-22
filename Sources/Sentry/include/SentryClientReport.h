#import "SentryDefines.h"
#import "SentrySerializable.h"

@class SentryDiscardedEvent;

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientReport : SENTRY_BASE_OBJECT <SentrySerializable>
SENTRY_NO_INIT

- (instancetype)initWithDiscardedEvents:(NSArray<SentryDiscardedEvent *> *)discardedEvents;

/**
 * The timestamp of when the client report was created.
 */
@property (nonatomic, strong, readonly) NSDate *timestamp;

@property (nonatomic, strong, readonly) NSArray<SentryDiscardedEvent *> *discardedEvents;

@end

NS_ASSUME_NONNULL_END
