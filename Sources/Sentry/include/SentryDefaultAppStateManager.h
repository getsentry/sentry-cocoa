#import "SentryDefines.h"

@class SentryAppState;
@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@class SentryFileManager;

@protocol SentryNSNotificationCenterWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface SentryDefaultAppStateManager : NSObject
SENTRY_NO_INIT

@property (nonatomic, readonly) NSInteger startCount;

- (instancetype)initWithStoreCurrent:(void (^)(void))storeCurrent
                    updateTerminated:(void (^)(void))updateTerminated
                 updateSDKNotRunning:(void (^)(void))updateSDKNotRunning
                        updateActive:(void (^)(BOOL))updateActive;

#if SENTRY_HAS_UIKIT

- (void)start;
- (void)stop;
- (void)stopWithForce:(BOOL)forceStop;

#endif

@end

NS_ASSUME_NONNULL_END
