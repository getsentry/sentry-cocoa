#import "SentryANRTrackingIntegration.h"
#import "SentryClient+Private.h"
#import "SentryCrashMachineContext.h"
#import "SentryCrashWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryFileManager.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryMechanism.h"
#import "SentrySDK+Private.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import "SentryThread.h"
#import "SentryThreadInspector.h"
#import "SentryThreadWrapper.h"
#import "SentryUIApplication.h"
#import <SentryOptions+Private.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryANRTrackingIntegration ()

@property (nonatomic, strong) id<SentryANRTracker> tracker;
@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (atomic, assign) BOOL reportAppHangs;
@property (atomic, assign) BOOL enableReportNonFullyBlockingAppHangs;

@end

@implementation SentryANRTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

#if SENTRY_HAS_UIKIT
    self.tracker =
        [SentryDependencyContainer.sharedInstance getANRTracker:options.appHangTimeoutInterval
                                                    isV2Enabled:options.enableAppHangTrackingV2];
#else
    self.tracker =
        [SentryDependencyContainer.sharedInstance getANRTracker:options.appHangTimeoutInterval];

#endif // SENTRY_HAS_UIKIT
    self.fileManager = SentryDependencyContainer.sharedInstance.fileManager;
    self.dispatchQueueWrapper = SentryDependencyContainer.sharedInstance.dispatchQueueWrapper;
    [self.tracker addListener:self];
    self.options = options;
    self.reportAppHangs = YES;

    [self captureStoredAppHangEvent];

    return YES;
}

/**
 * It can happen that an app crashes while waiting for the app hang to stop. Therefore, we send the
 * app hang without a duration as it was stored.
 */
- (void)captureStoredAppHangEvent
{
    __weak SentryANRTrackingIntegration *weakSelf = self;
    [self.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        if (weakSelf == nil) {
            return;
        }

        SentryEvent *event = [weakSelf.fileManager readAppHangEvent];
        if (event == nil) {
            return;
        }

        [weakSelf.fileManager deleteAppHangEvent];
        [SentrySDK captureEvent:event];
    }];
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAppHangTracking | kIntegrationOptionDebuggerNotAttached;
}

- (void)pauseAppHangTracking
{
    self.reportAppHangs = NO;
}

- (void)resumeAppHangTracking
{
    self.reportAppHangs = YES;
}

- (void)uninstall
{
    [self.tracker removeListener:self];
}

- (void)dealloc
{
    [self uninstall];
}

- (void)anrDetectedWithType:(enum SentryANRType)type
{
    if (self.reportAppHangs == NO) {
        SENTRY_LOG_DEBUG(@"AppHangTracking paused. Ignoring reported app hang.")
        return;
    }

#if SENTRY_HAS_UIKIT
    if (type == SentryANRTypeNonFullyBlocking
        && !self.options.enableReportNonFullyBlockingAppHangs) {
        SENTRY_LOG_DEBUG(@"Ignoring non fully blocking app hang.")
        return;
    }

    // If the app is not active, the main thread may be blocked or too busy.
    // Since there is no UI for the user to interact, there is no need to report app hang.
    if (SentryDependencyContainer.sharedInstance.application.applicationState
        != UIApplicationStateActive) {
        return;
    }
#endif
    SentryThreadInspector *threadInspector = SentrySDK.currentHub.getClient.threadInspector;

    NSArray<SentryThread *> *threads = [threadInspector getCurrentThreadsWithStackTrace];

    if (threads.count == 0) {
        SENTRY_LOG_WARN(@"Getting current thread returned an empty list. Can't create AppHang "
                        @"event without a stacktrace.");
        return;
    }

    NSString *message = [NSString stringWithFormat:@"App hanging for at least %li ms.",
        (long)(self.options.appHangTimeoutInterval * 1000)];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];

    NSString *exceptionType = [SentryAppHangTypeMapper getExceptionTypeWithAnrType:type];
    SentryException *sentryException = [[SentryException alloc] initWithValue:message
                                                                         type:exceptionType];

    sentryException.mechanism = [[SentryMechanism alloc] initWithType:@"AppHang"];
    sentryException.stacktrace = [threads[0] stacktrace];
    sentryException.stacktrace.snapshot = @(YES);

    [threads enumerateObjectsUsingBlock:^(SentryThread *_Nonnull obj, NSUInteger idx,
        BOOL *_Nonnull stop) { obj.current = [NSNumber numberWithBool:idx == 0]; }];

    event.exceptions = @[ sentryException ];
    event.threads = threads;

    // We only measure app hang duration for V2.
    // For V1, we directly capture the app hang event.
    if (self.options.enableAppHangTrackingV2) {
        [self.fileManager storeAppHangEvent:event];
    } else {
        [SentrySDK captureEvent:event];
    }
}

- (void)anrStoppedWithResult:(SentryANRStoppedResult *_Nullable)result
{
    // We only measure app hang duration for V2, and therefore ignore V1.
    if (!self.options.enableAppHangTrackingV2) {
        return;
    }

    if (result == nil) {
        SENTRY_LOG_WARN(@"ANR stopped for V2 but result was nil.")
        return;
    }

    SentryEvent *event = [self.fileManager readAppHangEvent];
    if (event == nil) {
        SENTRY_LOG_WARN(@"AppHang stopped but stored app hang event was nil.")
        return;
    }

    [self.fileManager deleteAppHangEvent];

    // We round to 0.1 seconds accuracy because we can't precicely measure the app hand duration.
    NSString *errorMessage =
        [NSString stringWithFormat:@"App hanging between %.1f and %.1f seconds.",
            result.minDuration, result.maxDuration];

    event.exceptions.firstObject.value = errorMessage;
    [SentrySDK captureEvent:event];
}

@end

NS_ASSUME_NONNULL_END
