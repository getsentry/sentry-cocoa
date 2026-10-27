#import "SentryDependencyContainerSwiftHelper.h"
#import "SentryClient+Private.h"
#import "SentryHub+Private.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"
#if SENTRY_TARGET_PROFILING_SUPPORTED && SENTRY_HAS_UIKIT
#    import "Profiling/SentryProfilingScreenFramesHelper.h"
#endif

#if SENTRY_TARGET_PROFILING_SUPPORTED

void
sentry_bootstrapProfilerSDKAdapter(void)
{
    // Accessing the initial container registers its backend before +load starts launch profiling.
    (void)[SentryDependencyContainer sharedInstance];
}

@implementation SentryDefaultProfilerSDKBackend
- (void)activate
{
    [SentryProfilerSDKAdapter.shared setTarget:self];
}
- (void)dealloc
{
    [SentryProfilerSDKAdapter.shared removeTarget:self];
}

- (id<SentryCurrentDateProvider>)dateProvider
{
    return SentryDependencyContainer.sharedInstance.dateProvider;
}

- (SentryDebugImageProvider *)debugImageProvider
{
    return SentryDependencyContainer.sharedInstance.debugImageProvider;
}

- (SentryDispatchFactory *)dispatchFactory
{
    return SentryDependencyContainer.sharedInstance.dispatchFactory;
}

- (id<SentryProcessInfoSource>)processInfoWrapper
{
    return SentryDependencyContainer.sharedInstance.processInfoWrapper;
}

- (void)dispatchAsync:(dispatch_block_t)block
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:block];
}

- (NSDate *_Nullable)date
{
    return [SentryDependencyContainer.sharedInstance.dateProvider date];
}

- (uint64_t)systemTime
{
    return SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
}

- (void)dispatchAsyncOnQueue:(SentryDispatchQueueWrapper *)wrapper block:(dispatch_block_t)block
{
    [wrapper dispatchAsyncWithBlock:block];
}

- (void)dispatchAsyncOnMainIfNotMainThread:(dispatch_block_t)block
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper
        dispatchAsyncOnMainQueueIfNotMainThread:block];
}

- (void)removeObserver:(id)object
{
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper removeObserver:object
                                                                                  name:nil
                                                                                object:nil];
}

- (void)addObserver:(id)observer
           selector:(SEL)selector
               name:(NSNotificationName)name
             object:(id _Nullable)object
{
    return [SentryDependencyContainer.sharedInstance.notificationCenterWrapper addObserver:observer
                                                                                  selector:selector
                                                                                      name:name
                                                                                    object:object];
}

- (void)postNotification:(NSNotification *)notification
{
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        postNotification:notification];
}

- (id _Nullable)addObserverForName:(NSNotificationName)name block:(dispatch_block_t)block
{
    return [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
        addObserverForName:name
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull notification) { block(); }];
}

- (NSTimer *_Nullable)scheduledTimerWithInterval:(NSTimeInterval)interval
                                         repeats:(BOOL)repeats
                                           block:(dispatch_block_t)block
{
    return [SentryDependencyContainer.sharedInstance.timerFactory
        scheduledTimerWithTimeInterval:interval
                               repeats:repeats
                                 block:^(NSTimer *_Nonnull timer) { block(); }];
}

- (NSTimer *_Nullable)scheduledTimerWithInterval:(NSTimeInterval)interval
                                          target:(id)target
                                        selector:(SEL)selector
                                        userInfo:(id _Nullable)userInfo
                                         repeats:(BOOL)repeats
{
    return [SentryDependencyContainer.sharedInstance.timerFactory
        scheduledTimerWithTimeInterval:interval
                                target:target
                              selector:selector
                              userInfo:userInfo
                               repeats:repeats];
}

- (void)startLaunchProfile
{
    [SentryLaunchProfiling startLaunchProfile];
}

- (BOOL)isTracingAppLaunch
{
    return SentryLaunchProfiling.isTracingAppLaunch;
}

- (void)setIsTracingAppLaunch:(BOOL)isTracingAppLaunch
{
    SentryLaunchProfiling.isTracingAppLaunch = isTracingAppLaunch;
}

- (SentryTracer *_Nullable)launchTracer
{
    return (SentryTracer *)SentryLaunchProfiling.launchTracer;
}

#    if SENTRY_HAS_UIKIT

- (void)startFramesTracker
{
    [SentryDependencyContainer.sharedInstance.framesTracker start];
}

- (void)stopFramesTracker
{
    [SentryDependencyContainer.sharedInstance.framesTracker stop];
}

- (void)resetProfilingTimestamps
{
    [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
}

- (SentryScreenFrames *_Nullable)copyCurrentFrames
{
    return [SentryProfilingScreenFramesHelper
        copyScreenFrames:SentryDependencyContainer.sharedInstance.framesTracker.currentFrames];
}

#    endif // SENTRY_HAS_UIKIT

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@implementation SentryDependencyContainerSwiftHelper

#if SENTRY_HAS_UIKIT

+ (NSArray<UIWindow *> *)windows
{
    return [SentryDependencyContainer.sharedInstance.application getWindows];
}

#    if TARGET_OS_IOS || TARGET_OS_TV
+ (CGSize)activeScreenSize
{
    return [SentryDependencyContainer.sharedInstance.application getActiveWindowSize];
}
#    endif // TARGET_OS_IOS || TARGET_OS_TV

#endif // SENTRY_HAS_UIKIT

+ (NSString *)release:(SentryOptions *)options
{
    return options.releaseName;
}

+ (SentryLog *)beforeSendLog:(SentryLog *)log options:(SentryOptions *)options
{
    if (options.beforeSendLog) {
        return options.beforeSendLog(log);
    }
    return log;
}

+ (NSString *)environment:(SentryOptions *)options
{
    return options.environment;
}

+ (BOOL)enableLogs:(SentryOptions *)options
{
#if SDK_V10
    return YES;
#else
    return options.enableLogs;
#endif // SDK_V10
}

+ (NSArray<NSString *> *)enabledFeatures:(SentryOptions *)options
{
    return [SentryEnabledFeaturesBuilder getEnabledFeaturesWithOptions:options];
}

+ (SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    return SentryDependencyContainer.sharedInstance.dispatchQueueWrapper;
}

+ (void)dispatchSyncOnMainQueue:(void (^)(void))block
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchSyncOnMainQueue:block];
}

+ (nullable NSDate *)readTimestampLastInForeground
{
    SentryHubInternal *hub = [SentrySDKInternal currentHub];
    return [[[hub getClient] fileManager] readTimestampLastInForeground];
}

+ (void)deleteTimestampLastInForeground
{
    SentryHubInternal *hub = [SentrySDKInternal currentHub];
    [[[hub getClient] fileManager] deleteTimestampLastInForeground];
}

+ (void)storeTimestampLastInForeground:(NSDate *)timestamp
{
    SentryHubInternal *hub = [SentrySDKInternal currentHub];
    [[[hub getClient] fileManager] storeTimestampLastInForeground:timestamp];
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
+ (BOOL)hasProfilingOptions
{
    return SentrySDKInternal.currentHub.client.options.profiling != nil;
}
#endif

@end
