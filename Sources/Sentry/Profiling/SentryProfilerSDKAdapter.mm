#import "SentryProfilerSDKAdapter.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@implementation SentryProfilerSDKAdapter {
    __weak id<SentryProfilerSDKBackend> _target;
}

+ (SentryProfilerSDKAdapter *)shared
{
    static SentryProfilerSDKAdapter *adapter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ adapter = [[SentryProfilerSDKAdapter alloc] init]; });
    return adapter;
}

- (id<SentryProfilerSDKBackend>)target
{
    @synchronized(self) {
        return _target;
    }
}

- (void)setTarget:(id<SentryProfilerSDKBackend>)target
{
    @synchronized(self) {
        _target = target;
    }
}

- (void)removeTarget:(id<SentryProfilerSDKBackend>)target
{
    @synchronized(self) {
        // Cleanup from an older SDK lifecycle must not unregister its replacement.
        if (_target == target) {
            _target = nil;
        }
    }
}

- (SentryProfilingTimestamp)timestamp
{
    id<SentryProfilerSDKBackend> target = self.target;
    return target == nil ? (SentryProfilingTimestamp) { 0, 0 } : [target timestamp];
}

- (NSArray<NSDictionary<NSString *, id> *> *_Nullable)serializedDebugImages
{
    return [self.target serializedDebugImages];
}

- (SentryProfilingSystemMetrics *_Nullable)systemMetrics
{
    return [self.target systemMetrics];
}

- (id<SentryProfilingCancellation> _Nullable)
    scheduleMetricSamplingWithInterval:(uint64_t)intervalNanoseconds
                                leeway:(uint64_t)leewayNanoseconds
                                 block:(dispatch_block_t)block
{
    return [self.target scheduleMetricSamplingWithInterval:intervalNanoseconds
                                                    leeway:leewayNanoseconds
                                                     block:block];
}

- (id<SentryProfilingCancellation> _Nullable)scheduleTimerWithInterval:(NSTimeInterval)interval
                                                               repeats:(BOOL)repeats
                                                                 block:(dispatch_block_t)block
{
    return [self.target scheduleTimerWithInterval:interval repeats:repeats block:block];
}

- (void)dispatchAsync:(dispatch_block_t)block
{
    [self.target dispatchAsync:block];
}

- (NSDate *_Nullable)date
{
    return [self.target date];
}

- (uint64_t)systemTime
{
    return [self.target systemTime];
}

- (void)dispatchAsyncOnMainIfNotMainThread:(dispatch_block_t)block
{
    [self.target dispatchAsyncOnMainIfNotMainThread:block];
}

- (void)removeObserver:(id)object
{
    [self.target removeObserver:object];
}

- (void)addObserver:(id)observer
           selector:(SEL)selector
               name:(NSNotificationName)name
             object:(id _Nullable)object
{
    [self.target addObserver:observer selector:selector name:name object:object];
}

- (void)postNotification:(NSNotification *)notification
{
    [self.target postNotification:notification];
}

- (id _Nullable)addObserverForName:(NSNotificationName)name block:(dispatch_block_t)block
{
    return [self.target addObserverForName:name block:block];
}

- (void)startLaunchProfile
{
    [self.target startLaunchProfile];
}

- (BOOL)isTracingAppLaunch
{
    return [self.target isTracingAppLaunch];
}

- (void)setIsTracingAppLaunch:(BOOL)isTracingAppLaunch
{
    [self.target setIsTracingAppLaunch:isTracingAppLaunch];
}

#    if SENTRY_HAS_UIKIT

- (void)startFramesTracker
{
    [self.target startFramesTracker];
}

- (void)stopFramesTracker
{
    [self.target stopFramesTracker];
}

- (void)resetProfilingTimestamps
{
    [self.target resetProfilingTimestamps];
}

- (SentryProfilingFrameMeasurements *_Nullable)copyFrameMeasurements
{
    return [self.target copyFrameMeasurements];
}

#    endif // SENTRY_HAS_UIKIT

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
