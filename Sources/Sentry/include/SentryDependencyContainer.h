#import "SentryDefines.h"
#import "SentryRandom.h"
#import <Foundation/Foundation.h>

@class SentryAppStateManager, SentryCrashWrapper, SentryThreadWrapper, SentryDispatchQueueWrapper,
    SentrySwizzleWrapper, SentryDebugImageProvider;

#if SENTRY_HAS_UIKIT
@class SentryScreenshot, SentryUIApplication;
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
@property (nonatomic, strong) SentrySwizzleWrapper *swizzleWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryScreenshot *screenshot;
@property (nonatomic, strong) SentryUIApplication *application;
#endif

@end

NS_ASSUME_NONNULL_END
