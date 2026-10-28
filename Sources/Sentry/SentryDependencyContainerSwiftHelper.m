#import "SentryDependencyContainerSwiftHelper.h"
#import "SentryClient+Private.h"
#import "SentryHub+Private.h"
#import "SentryInternalSerializable.h"
#import "SentryLogC.h"
#import "SentryProfilerCancellation.h"
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

@implementation SentryDefaultProfilerSDKBackend {
    SentrySystemWrapper *_profilingSystemWrapper;
}
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

- (SentryProfilingTimestamp)timestamp
{
    id<SentryCurrentDateProvider> provider = self.dateProvider;
    uint64_t systemTime = provider.systemTime;
    NSTimeInterval dateInterval = provider.date.timeIntervalSince1970;
    return (SentryProfilingTimestamp) { systemTime, dateInterval };
}

- (NSArray<NSDictionary<NSString *, id> *> *_Nullable)serializedDebugImages
{
    SentryDebugImageProvider *provider = self.debugImageProvider;
    if (provider == nil) {
        return nil;
    }
    NSMutableArray<NSDictionary<NSString *, id> *> *images = [NSMutableArray array];
    for (SentryDebugMeta *image in [provider getDebugImagesFromCache]) {
        [images addObject:[image serialize]];
    }
    return [images copy];
}

- (SentrySystemWrapper *)profilingSystemWrapper
{
    @synchronized(self) {
        if (_profilingSystemWrapper == nil) {
            _profilingSystemWrapper = [[SentrySystemWrapper alloc]
                initWithProcessorCount:self.processInfoWrapper.processorCount];
        }
        return _profilingSystemWrapper;
    }
}

- (SentryProfilingSystemMetrics *)systemMetrics
{
    SentrySystemWrapper *wrapper = [self profilingSystemWrapper];
    NSError *cpuError = nil;
    NSNumber *cpuUsage = [wrapper cpuUsageAndReturnError:&cpuError];
    if (cpuError != nil) {
        SENTRY_LOG_ERROR(@"Failed to read CPU usages: %@", cpuError);
        cpuUsage = nil;
    }

    NSError *memoryError = nil;
    NSNumber *memoryFootprint = [wrapper memoryFootprintBytesAndReturnError:&memoryError];
    if (memoryError != nil) {
        SENTRY_LOG_ERROR(@"Failed to read memory footprint: %@", memoryError);
        memoryFootprint = nil;
    }

    NSNumber *energyUsage = nil;
#    if defined(__arm__) || defined(__arm64__)
    NSError *energyError = nil;
    energyUsage = [wrapper cpuEnergyUsageAndReturnError:&energyError];
    if (energyError != nil) {
        SENTRY_LOG_ERROR(@"Failed to read CPU energy usage: %@", energyError);
        energyUsage = nil;
    }
#    endif

    return [[SentryProfilingSystemMetrics alloc] initWithCPUUsage:cpuUsage
                                             memoryFootprintBytes:memoryFootprint
                                                   cpuEnergyUsage:energyUsage];
}

- (id<SentryProfilingCancellation> _Nullable)
    scheduleMetricSamplingWithInterval:(uint64_t)intervalNanoseconds
                                leeway:(uint64_t)leewayNanoseconds
                                 block:(dispatch_block_t)block
{
    SentryDispatchSourceWrapper *source = [self.dispatchFactory
        sourceWithInterval:intervalNanoseconds
                    leeway:leewayNanoseconds
                 queueName:"io.sentry.metric-profiler"
                attributes:dispatch_queue_attr_make_with_qos_class(
                               DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_UTILITY, 0)
              eventHandler:block];
    if (source == nil) {
        return nil;
    }
    return [[SentryProfilerCancellation alloc] initWithCancellation:^{ [source cancel]; }];
}

- (id<SentryProfilingCancellation> _Nullable)scheduleTimerWithInterval:(NSTimeInterval)interval
                                                               repeats:(BOOL)repeats
                                                                 block:(dispatch_block_t)block
{
    NSTimer *timer = [self scheduledTimerWithInterval:interval repeats:repeats block:block];
    if (timer == nil) {
        return nil;
    }
    return [[SentryProfilerCancellation alloc] initWithCancellation:^{ [timer invalidate]; }];
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

- (SentryProfilingFrameMeasurements *_Nullable)copyFrameMeasurements
{
    SentryScreenFrames *frames = [self copyCurrentFrames];
    if (frames == nil) {
        return nil;
    }
    return [[SentryProfilingFrameMeasurements alloc]
        initWithSlowFrameTimestamps:frames.slowFrameTimestamps
              frozenFrameTimestamps:frames.frozenFrameTimestamps
                frameRateTimestamps:frames.frameRateTimestamps];
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
