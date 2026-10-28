#import "SentryDefaultProfilerSDKBackend.h"
#import "SentryClient+Private.h"
#import "SentryHub+Private.h"
#import "SentryInternalSerializable.h"
#import "SentryLogC.h"
#import "SentryProfilerCancellation.h"
#import "SentryProfilerConfigurationBridge.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

void
sentry_bootstrapProfilerSDKAdapter(void)
{
    // Accessing the initial container registers its backend before +load starts launch profiling.
    (void)[SentryDependencyContainer sharedInstance];
}

@implementation SentryDefaultProfilerSDKBackend {
    SentrySystemWrapper *_systemWrapper;
}
- (void)activate
{
    [SentryProfilerSDKAdapter.shared setTarget:self];
}
- (void)dealloc
{
    [SentryProfilerSDKAdapter.shared removeTarget:self];
}

- (SentryProfilingConfiguration)configuration
{
    return sentry_profilerConfigurationSnapshot();
}

- (SentryProfilingTimestamp)timestamp
{
    id<SentryCurrentDateProvider> provider = SentryDependencyContainer.sharedInstance.dateProvider;
    uint64_t systemTime = provider.systemTime;
    NSTimeInterval dateInterval = provider.date.timeIntervalSince1970;
    return (SentryProfilingTimestamp) { systemTime, dateInterval };
}

- (NSArray<NSDictionary<NSString *, id> *> *_Nullable)serializedDebugImages
{
    SentryDebugImageProvider *provider
        = SentryDependencyContainer.sharedInstance.debugImageProvider;
    if (provider == nil) {
        return nil;
    }
    NSMutableArray<NSDictionary<NSString *, id> *> *images = [NSMutableArray array];
    for (SentryDebugMeta *image in [provider getDebugImagesFromCache]) {
        [images addObject:[image serialize]];
    }
    return [images copy];
}

- (SentrySystemWrapper *)systemWrapper
{
    @synchronized(self) {
        if (_systemWrapper == nil) {
            _systemWrapper = [[SentrySystemWrapper alloc]
                initWithProcessorCount:SentryDependencyContainer.sharedInstance.processInfoWrapper
                                           .processorCount];
        }
        return _systemWrapper;
    }
}

- (void)setSystemWrapper:(SentrySystemWrapper *)systemWrapper
{
    @synchronized(self) {
        _systemWrapper = systemWrapper;
    }
}

- (SentryProfilingSystemMetrics *)systemMetrics
{
    SentrySystemWrapper *wrapper = self.systemWrapper;
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
    SentryDispatchSourceWrapper *source = [SentryDependencyContainer.sharedInstance.dispatchFactory
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
    NSTimer *timer = [SentryDependencyContainer.sharedInstance.timerFactory
        scheduledTimerWithTimeInterval:interval
                               repeats:repeats
                                 block:^(__unused NSTimer *firedTimer) { block(); }];
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

#    if SENTRY_HAS_UIKIT

- (void)startFramesTracker
{
    [SentryDependencyContainer.sharedInstance.framesTracker start];
}

- (void)stopFramesTrackerIfUnused
{
    // Automatic performance tracing and app hang tracking may still need the frames tracker.
    SentryOptions *performanceOptions = [[[SentrySDKInternal currentHub] getClient] options];
    BOOL shouldStop = performanceOptions == nil || !performanceOptions.enableAutoPerformanceTracing;
#        if !SDK_V10
    SentryOptions *appHangOptions = [[[SentrySDKInternal currentHub] getClient] options];
    BOOL appHangsDisabled = appHangOptions != nil && [appHangOptions isAppHangTrackingDisabled];
    shouldStop = shouldStop && appHangsDisabled;
#        endif
    if (shouldStop) {
        [SentryDependencyContainer.sharedInstance.framesTracker stop];
    }
}

- (void)resetProfilingTimestamps
{
    [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
}

- (SentryProfilingFrameMeasurements *_Nullable)copyFrameMeasurements
{
    SentryScreenFrames *frames
        = SentryDependencyContainer.sharedInstance.framesTracker.currentFrames;
    if (frames == nil) {
        return nil;
    }
    return [[SentryProfilingFrameMeasurements alloc]
        initWithSlowFrameTimestamps:frames.slowFrameTimestamps
              frozenFrameTimestamps:frames.frozenFrameTimestamps
                frameRateTimestamps:frames.frameRateTimestamps];
}

#    endif // SENTRY_HAS_UIKIT

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
