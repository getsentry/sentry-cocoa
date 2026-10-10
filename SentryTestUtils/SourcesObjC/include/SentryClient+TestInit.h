#import "SentryDefines.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

// Swift-owned parameters must be erased at this Clang boundary. The selector still invokes
// the real SDK initializer, not the mock client's overrides.
@interface SentryClientInternal (TestInit)

- (instancetype)
         initWithOptions:(NSObject *)options
            dateProvider:(SENTRY_SWIFT_MIGRATION_ID(id<SentryCurrentDateProvider>))dateProvider
        transportAdapter:(SENTRY_SWIFT_MIGRATION_ID(SentryTransportAdapter))transportAdapter
             fileManager:(SENTRY_SWIFT_MIGRATION_ID(SentryFileManager))fileManager
         threadInspector:(SENTRY_SWIFT_MIGRATION_ID(SentryDefaultThreadInspector))threadInspector
      debugImageProvider:(SENTRY_SWIFT_MIGRATION_ID(SentryDebugImageProvider))debugImageProvider
                  random:(SENTRY_SWIFT_MIGRATION_ID(id<SentryRandomProtocol>))random
                  locale:(NSLocale *)locale
                timezone:(NSTimeZone *)timezone
    eventContextEnricher:(SENTRY_SWIFT_MIGRATION_ID(
                             id<SentryEventContextEnricher>))eventContextEnricher
        binaryImageCache:(SENTRY_SWIFT_MIGRATION_ID(SentryBinaryImageCache))binaryImageCache
    dispatchQueueWrapper:(SENTRY_SWIFT_MIGRATION_ID(SentryDispatchQueueWrapper))dispatchQueueWrapper
    NS_SWIFT_NAME(init(testOptions:dateProvider:transportAdapter:fileManager:threadInspector:debugImageProvider:random:locale:timezone:eventContextEnricher:binaryImageCache:dispatchQueueWrapper:));

@end

NS_ASSUME_NONNULL_END
