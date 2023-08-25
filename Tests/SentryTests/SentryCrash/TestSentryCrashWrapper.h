#import "SentryCrashWrapper.h"
#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Written in Objective-C because Swift doesn't allow you to call the constructor of
 * TestSentryCrashAdapter. We override sharedInstance in the implementation file to make it work.
 */
@interface TestSentryCrashWrapper : SentryCrashWrapper
SENTRY_NO_INIT

@property (nonatomic, assign) BOOL internalCrashedLastLaunch;

@property (nonatomic, assign) NSTimeInterval internalDurationFromCrashStateInitToLastCrash;

@property (nonatomic, assign) NSTimeInterval internalActiveDurationSinceLastCrash;

@property (nonatomic, assign) BOOL internalIsBeingTraced;

@property (nonatomic, assign) BOOL internalIsSimulatorBuild;

@property (nonatomic, assign) BOOL internalIsApplicationInForeground;

@property (nonatomic, assign) BOOL installAsyncHooksCalled;

@property (nonatomic, assign) BOOL uninstallAsyncHooksCalled;

@property (nonatomic, assign) uint64_t internalFreeMemorySize;

@property (nonatomic, assign) uint64_t internalAppMemorySize;

@property (nonatomic, assign) uint64_t internalFreeStorageSize;

@property (nonatomic) BOOL binaryCacheStarted;

@property (nonatomic) BOOL binaryCacheStopped;

@end

NS_ASSUME_NONNULL_END
