#import "SentryDefines.h"
#import "SentryProfilingCancellation.h"
#import "SentryProfilingConditionals.h"
#import "SentryProfilingConfiguration.h"
#import "SentryProfilingFrameMeasurements.h"
#import "SentryProfilingSystemMetrics.h"
#import "SentryProfilingTimestamp.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@protocol SentryProfilerSDKBackend <NSObject>

- (SentryProfilingConfiguration)configuration;
- (SentryProfilingTimestamp)timestamp;
- (NSArray<NSDictionary<NSString *, id> *> *_Nullable)serializedDebugImages;
- (SentryProfilingSystemMetrics *_Nullable)systemMetrics;
- (id<SentryProfilingCancellation> _Nullable)
    scheduleMetricSamplingWithInterval:(uint64_t)intervalNanoseconds
                                leeway:(uint64_t)leewayNanoseconds
                                 block:(dispatch_block_t)block;
- (id<SentryProfilingCancellation> _Nullable)scheduleTimerWithInterval:(NSTimeInterval)interval
                                                               repeats:(BOOL)repeats
                                                                 block:(dispatch_block_t)block;

- (NSDate *_Nullable)date;
- (uint64_t)systemTime;
- (void)dispatchAsync:(dispatch_block_t)block;
- (void)dispatchAsyncOnMainIfNotMainThread:(dispatch_block_t)block;
- (void)addObserver:(id)observer // OK: NotificationCenter accepts arbitrary observer objects.
           selector:(SEL)selector
               name:(NSNotificationName)name
             object:(id _Nullable)object;
- (void)removeObserver:(id)observer; // OK: Observer tokens and selector observers share this API.
- (void)postNotification:(NSNotification *)notification;
- (id _Nullable)addObserverForName:(NSNotificationName)name block:(dispatch_block_t)block;
- (void)startLaunchProfile;
@property (nonatomic) BOOL isTracingAppLaunch;

#    if SENTRY_HAS_UIKIT
- (void)startFramesTracker;
- (void)stopFramesTracker;
- (void)stopFramesTrackerIfUnused;
- (void)resetProfilingTimestamps;
- (SentryProfilingFrameMeasurements *_Nullable)copyFrameMeasurements;
#    endif

@end

// Process-lifetime access to the backend owned by the current SDK dependency container.
@interface SentryProfilerSDKAdapter : NSObject <SentryProfilerSDKBackend>

@property (class, nonatomic, readonly) SentryProfilerSDKAdapter *shared;
@property (nonatomic, readonly, nullable) id<SentryProfilerSDKBackend> target;

- (void)setTarget:(id<SentryProfilerSDKBackend>)target;
- (void)removeTarget:(id<SentryProfilerSDKBackend>)target;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
