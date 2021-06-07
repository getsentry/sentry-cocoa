#import "SentryCurrentDateProvider.h"
#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryCrashAdapter, SentryDispatchQueueWrapper, SentryFileManager;

/**
 * The dependency container for the SDK.
 */
@interface SentryDependencies : NSObject
SENTRY_NO_INIT

@property (nonatomic, class, readonly) id<SentryCurrentDateProvider> currentDateProvider;

@property (nonatomic, class, readonly) SentryCrashAdapter *crashAdapter;

@property (nonatomic, class, readonly) SentryDispatchQueueWrapper *dispatchQueue;

@end

NS_ASSUME_NONNULL_END
