#import <Foundation/Foundation.h>
#import "SentryCompatLastRunStatus.h"

@class SentryCompatOptions;
@class SentryCompatScope;
@class SentryCompatEvent;
@class SentryCompatId;
@class SentryCompatSpan;
@class SentryCompatTransactionContext;
@class SentryCompatBreadcrumb;
@class SentryCompatUser;
@class SentryCompatFeedback;
@class SentryCompatFeedbackAPI;

NS_ASSUME_NONNULL_BEGIN

/// Pure-Swift ObjC shim around the Sentry SDK. Consumers that need
/// Objective-C interop should call these APIs instead of `SentrySDK` directly.
@interface SentryCompat : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

// MARK: Lifecycle

+ (void)startWithOptions:(SentryCompatOptions *)options;
+ (void)startWithConfigureOptions:(void (^)(SentryCompatOptions *))configureOptions;
@property (class, nonatomic, readonly) BOOL isEnabled;
+ (void)flush:(NSTimeInterval)timeout;
+ (void)close;

// MARK: Crash status

@property (class, nonatomic, readonly) BOOL crashedLastRun
    __attribute__((deprecated("Use lastRunStatus instead, which distinguishes between 'did not crash' and 'unknown'.")));
@property (class, nonatomic, readonly) SentryCompatLastRunStatus lastRunStatus;
@property (class, nonatomic, readonly) BOOL detectedStartUpCrash;
+ (void)crash;

// MARK: Sessions

+ (void)startSession;
+ (void)endSession;

// MARK: App-hang tracking

+ (void)pauseAppHangTracking;
+ (void)resumeAppHangTracking;
+ (void)reportFullyDisplayed;

// MARK: Tracing

@property (class, nonatomic, readonly, strong, nullable) SentryCompatSpan *span;

+ (SentryCompatSpan *)startTransactionWithName:(NSString *)name
                                      operation:(NSString *)operation;
+ (SentryCompatSpan *)startTransactionWithName:(NSString *)name
                                      operation:(NSString *)operation
                                    bindToScope:(BOOL)bindToScope;
+ (SentryCompatSpan *)startTransactionWithContext:(SentryCompatTransactionContext *)transactionContext;
+ (SentryCompatSpan *)startTransactionWithContext:(SentryCompatTransactionContext *)transactionContext
                                      bindToScope:(BOOL)bindToScope;
+ (SentryCompatSpan *)startTransactionWithContext:(SentryCompatTransactionContext *)transactionContext
                                      bindToScope:(BOOL)bindToScope
                            customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;
+ (SentryCompatSpan *)startTransactionWithContext:(SentryCompatTransactionContext *)transactionContext
                            customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

// MARK: Event capture

+ (SentryCompatId *)captureEvent:(SentryCompatEvent *)event;
+ (SentryCompatId *)captureEvent:(SentryCompatEvent *)event withScope:(SentryCompatScope *)scope;
+ (SentryCompatId *)captureEvent:(SentryCompatEvent *)event
                  withScopeBlock:(void (^)(SentryCompatScope *))block;
+ (SentryCompatId *)captureEvent:(SentryCompatEvent *)event attachAllThreads:(BOOL)attachAllThreads;

+ (SentryCompatId *)captureError:(NSError *)error;
+ (SentryCompatId *)captureError:(NSError *)error withScope:(SentryCompatScope *)scope;
+ (SentryCompatId *)captureError:(NSError *)error
                  withScopeBlock:(void (^)(SentryCompatScope *))block;
+ (SentryCompatId *)captureError:(NSError *)error attachAllThreads:(BOOL)attachAllThreads;

+ (SentryCompatId *)captureException:(NSException *)exception;
+ (SentryCompatId *)captureException:(NSException *)exception withScope:(SentryCompatScope *)scope;
+ (SentryCompatId *)captureException:(NSException *)exception
                      withScopeBlock:(void (^)(SentryCompatScope *))block;
+ (SentryCompatId *)captureException:(NSException *)exception
                    attachAllThreads:(BOOL)attachAllThreads;

+ (SentryCompatId *)captureMessage:(NSString *)message;
+ (SentryCompatId *)captureMessage:(NSString *)message withScope:(SentryCompatScope *)scope;
+ (SentryCompatId *)captureMessage:(NSString *)message
                    withScopeBlock:(void (^)(SentryCompatScope *))block;
+ (SentryCompatId *)captureMessage:(NSString *)message attachAllThreads:(BOOL)attachAllThreads;

+ (void)captureFeedback:(SentryCompatFeedback *)feedback;

/// The user-feedback API; iOS only.
@property (class, nonatomic, readonly, strong) SentryCompatFeedbackAPI *feedback;

// MARK: Breadcrumbs / scope / user

+ (void)addBreadcrumb:(SentryCompatBreadcrumb *)crumb;
+ (void)configureScope:(void (^)(SentryCompatScope *))callback;
+ (void)setUser:(nullable SentryCompatUser *)user;

// MARK: Continuous profiling

+ (void)startProfiler;
+ (void)stopProfiler;

@end

NS_ASSUME_NONNULL_END
