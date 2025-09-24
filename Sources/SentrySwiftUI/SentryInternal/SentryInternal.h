/**
 * SentrySwiftUI needs a class from Sentry that is not public.
 * The easiest way do expose this class is by copying it interface.
 * We could just add the original header file to SwntrySwiftUI project,
 * but the original file has reference to other header that we don't need here.
 */

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/Sentry.h>
#elif __has_include("Sentry.h")
#    import "Sentry.h"
#endif

#if __has_include("SentrySDKInternal.h")
#    include "SentrySDKInternal.h"
#endif

#if SENTRY_TEST
#    import "SentrySpan.h"
#    import "SentryTracer.h"
#else
@class SentrySpan;
@interface SentryTracer : NSObject <SentrySpan>
@end
#endif

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SENTRY_XCODE_PREVIEW_ENVIRONMENT_KEY;

typedef NS_ENUM(NSInteger, SentryTransactionNameSource);

@class SentryDispatchQueueWrapper;

@interface SentryTimeToDisplayTracker : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nullable, nonatomic, weak, readonly) SentrySpan *initialDisplaySpan;

@property (nullable, nonatomic, weak, readonly) SentrySpan *fullDisplaySpan;

@property (nonatomic, readonly) BOOL waitForFullDisplay;

- (instancetype)initWithName:(NSString *)name
          waitForFullDisplay:(BOOL)waitForFullDisplay
        dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

- (instancetype)initWithName:(NSString *)name waitForFullDisplay:(BOOL)waitForFullDisplay;

- (BOOL)startForTracer:(SentryTracer *)tracer;

- (void)reportInitialDisplay;

- (void)reportFullyDisplayed;

- (void)finishSpansIfNotFinished;

@end

@interface SentryUIViewControllerPerformanceTracker : NSObject

- (void)reportFullyDisplayed;

- (nullable SentryTimeToDisplayTracker *)startTimeToDisplayTrackerForScreen:(NSString *)screenName
                                                         waitForFullDisplay:(BOOL)waitForFullDisplay
                                                                     tracer:(SentryTracer *)tracer;

@end

#if __has_include("SentrySDKInternal.h")
@interface SentrySDKInternal ()
#else
@interface SentrySDKInternal : NSObject
#endif

@property (nonatomic, nullable, readonly, class) SentryOptions *options;
+ (void)setCurrentHub:(nullable SentryHub *)hub;
+ (void)setStartOptions:(nullable SentryOptions *)options NS_SWIFT_NAME(setStart(with:));

@end

NS_ASSUME_NONNULL_END
