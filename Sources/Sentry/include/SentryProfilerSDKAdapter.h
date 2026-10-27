#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryDebugImageProvider;
@class SentryDispatchFactory;
@class SentryDispatchQueueWrapper;
@class SentryScreenFrames;
@class SentryTracer;
@protocol SentryProcessInfoSource;
@protocol SentryCurrentDateProvider;

NS_ASSUME_NONNULL_BEGIN

@protocol SentryProfilerSDKBackend <NSObject>

@property (nonatomic, readonly, nullable) id<SentryCurrentDateProvider> dateProvider;
@property (nonatomic, readonly, nullable) SentryDebugImageProvider *debugImageProvider;
@property (nonatomic, readonly, nullable) SentryDispatchFactory *dispatchFactory;
@property (nonatomic, readonly, nullable) id<SentryProcessInfoSource> processInfoWrapper;

- (NSDate *_Nullable)date;
- (uint64_t)systemTime;
- (void)dispatchAsync:(dispatch_block_t)block;
- (void)dispatchAsyncOnQueue:(SentryDispatchQueueWrapper *)queue block:(dispatch_block_t)block;
- (void)dispatchAsyncOnMainIfNotMainThread:(dispatch_block_t)block;
- (void)addObserver:(id)observer // OK: NotificationCenter accepts arbitrary observer objects.
           selector:(SEL)selector
               name:(NSNotificationName)name
             object:(id _Nullable)object;
- (void)removeObserver:(id)observer; // OK: Observer tokens and selector observers share this API.
- (void)postNotification:(NSNotification *)notification;
- (id _Nullable)addObserverForName:(NSNotificationName)name block:(dispatch_block_t)block;
- (NSTimer *_Nullable)scheduledTimerWithInterval:(NSTimeInterval)interval
                                         repeats:(BOOL)repeats
                                           block:(dispatch_block_t)block;
- (NSTimer *_Nullable)
    scheduledTimerWithInterval:(NSTimeInterval)interval
                        target:(id)target // OK: NSTimer invokes a selector on an arbitrary target.
                      selector:(SEL)selector
                      userInfo:(id _Nullable)userInfo
                       repeats:(BOOL)repeats;
- (void)startLaunchProfile;
@property (nonatomic) BOOL isTracingAppLaunch;
@property (nonatomic, readonly, nullable) SentryTracer *launchTracer;

#    if SENTRY_HAS_UIKIT
- (void)startFramesTracker;
- (void)stopFramesTracker;
- (void)resetProfilingTimestamps;
- (SentryScreenFrames *_Nullable)copyCurrentFrames;
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
