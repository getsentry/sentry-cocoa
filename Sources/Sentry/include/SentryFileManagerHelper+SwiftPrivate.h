#import "SentryFileManagerHelper.h"

NS_ASSUME_NONNULL_BEGIN

#if !SDK_V10
@interface SentryFileManagerHelper (SwiftPrivate)

- (void)storeAppHangEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))appHangEvent
    NS_SWIFT_NAME(storeAppHang(_:));

- (nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))readAppHangEvent;

@end
#endif // !SDK_V10

NS_ASSUME_NONNULL_END
