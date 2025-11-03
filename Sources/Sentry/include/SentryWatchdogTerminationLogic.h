#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class SentryAppState;
@class SentryAppStateManager;
@class SentryCrashWrapper;
@class SentryFileManager;
@class SentryOptionsInternal;

NS_ASSUME_NONNULL_BEGIN

@interface SentryWatchdogTerminationLogic : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptionsInternal *)options
                   crashAdapter:(SentryCrashWrapper *)crashAdapter
                appStateManager:(SentryAppStateManager *)appStateManager;

- (BOOL)isWatchdogTermination;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
