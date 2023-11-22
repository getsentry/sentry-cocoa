#import "SentryDataCategory.h"
#import "SentryDefines.h"
#import "SentryDiscardReason.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryDiscardedEvent : SENTRY_BASE_OBJECT <SentrySerializable>
SENTRY_NO_INIT

- (instancetype)initWithReason:(SentryDiscardReason)reason
                      category:(SentryDataCategory)category
                      quantity:(NSUInteger)quantity;

@property (nonatomic, assign, readonly) SentryDiscardReason reason;
@property (nonatomic, assign, readonly) SentryDataCategory category;
@property (nonatomic, assign, readonly) NSUInteger quantity;

@end

NS_ASSUME_NONNULL_END
