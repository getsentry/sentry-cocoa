#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryAppStateManager, SentryCrashAdapter, SentryThreadWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface SentryDependencyContainer : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

/**
 * Set all dependencies to nil for testing purposes.
 */
+ (void)reset;

@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentryCrashAdapter *crashAdapter;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;

@end

NS_ASSUME_NONNULL_END
