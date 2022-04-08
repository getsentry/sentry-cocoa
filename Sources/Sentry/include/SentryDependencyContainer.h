#import "SentryDefines.h"
#import "SentryRandom.h"
#import <Foundation/Foundation.h>

@class SentryAppStateManager, SentryCrashWrapper, SentryThreadWrapper;
#if SENTRY_HAS_UIKIT
@class SentryScreenshot;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryDependencyContainer : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

/**
 * Set all dependencies to nil for testing purposes.
 */
+ (void)reset;

@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;
@property (nonatomic, strong) id<SentryRandom> random;

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryScreenshot *screenshot;
#endif

@end

NS_ASSUME_NONNULL_END
