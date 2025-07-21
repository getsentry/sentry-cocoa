#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif // SENTRY_HAS_UIKIT

@protocol SentryObjCRuntimeWrapper;

@class SentryUserFeedbackIntegration;
@class SentryHub;
@class SentryDispatchQueueWrapper;
@protocol SentryCurrentDateProvider;

NS_ASSUME_NONNULL_BEGIN

@protocol SentryInternalCurrentDateProvider <NSObject>

- (NSDate *)date;

- (NSInteger)timezoneOffset;

- (uint64_t)systemTime;

- (NSTimeInterval)systemUptime;

@end

// Some Swift code needs to access Sentry types that we don’t want to completely
// expose to Swift. This class is exposed to Swift
// and bridges some functionality from without importing large amounts of the
// codebase to Swift.
@interface SentrySwiftHelpers : NSObject

#if SENTRY_HAS_UIKIT

+ (nullable NSArray<UIWindow *> *)windows;

#endif // SENTRY_HAS_UIKIT

+ (void)dispatchSyncOnMainQueue:(void (^)(void))block;
+ (id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper;
+ (id<SentryInternalCurrentDateProvider>)currentDateProvider;

+ (SentryHub *)currentHub;

@end

NS_ASSUME_NONNULL_END
