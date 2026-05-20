#import <Foundation/Foundation.h>
#import "SOCSentryLastRunStatus.h"

@class SOCSentryOptions;
@class SOCSentryScope;
@class SOCSentryEvent;
@class SOCSentryId;
@class SOCSentrySpan;
@class SOCSentryTransactionContext;
@class SOCSentryBreadcrumb;
@class SOCSentryUser;
@class SOCSentryFeedback;
@class SOCSentryFeedbackAPI;

NS_ASSUME_NONNULL_BEGIN

/// Pure-Swift ObjC shim around the Sentry SDK. Consumers that need
/// Objective-C interop should call these APIs instead of `SentrySDK` directly.
@interface SOCSentrySDK : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

// MARK: Lifecycle

+ (void)startWithOptions:(SOCSentryOptions *)options;
+ (void)startWithConfigureOptions:(void (^)(SOCSentryOptions *))configureOptions;
@property (class, nonatomic, readonly) BOOL isEnabled;
+ (void)flush:(NSTimeInterval)timeout;
+ (void)close;

// MARK: Crash status

@property (class, nonatomic, readonly) BOOL crashedLastRun
    __attribute__((deprecated("Use lastRunStatus instead, which distinguishes between 'did not crash' and 'unknown'.")));
@property (class, nonatomic, readonly) SOCSentryLastRunStatus lastRunStatus;
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

@property (class, nonatomic, readonly, strong, nullable) SOCSentrySpan *span;

+ (SOCSentrySpan *)startTransactionWithName:(NSString *)name
                                      operation:(NSString *)operation;
+ (SOCSentrySpan *)startTransactionWithName:(NSString *)name
                                      operation:(NSString *)operation
                                    bindToScope:(BOOL)bindToScope;
+ (SOCSentrySpan *)startTransactionWithContext:(SOCSentryTransactionContext *)transactionContext;
+ (SOCSentrySpan *)startTransactionWithContext:(SOCSentryTransactionContext *)transactionContext
                                      bindToScope:(BOOL)bindToScope;
+ (SOCSentrySpan *)startTransactionWithContext:(SOCSentryTransactionContext *)transactionContext
                                      bindToScope:(BOOL)bindToScope
                            customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;
+ (SOCSentrySpan *)startTransactionWithContext:(SOCSentryTransactionContext *)transactionContext
                            customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

// MARK: Event capture

+ (SOCSentryId *)captureEvent:(SOCSentryEvent *)event;
+ (SOCSentryId *)captureEvent:(SOCSentryEvent *)event withScope:(SOCSentryScope *)scope;
+ (SOCSentryId *)captureEvent:(SOCSentryEvent *)event
                  withScopeBlock:(void (^)(SOCSentryScope *))block;
+ (SOCSentryId *)captureEvent:(SOCSentryEvent *)event attachAllThreads:(BOOL)attachAllThreads;

+ (SOCSentryId *)captureError:(NSError *)error;
+ (SOCSentryId *)captureError:(NSError *)error withScope:(SOCSentryScope *)scope;
+ (SOCSentryId *)captureError:(NSError *)error
                  withScopeBlock:(void (^)(SOCSentryScope *))block;
+ (SOCSentryId *)captureError:(NSError *)error attachAllThreads:(BOOL)attachAllThreads;

+ (SOCSentryId *)captureException:(NSException *)exception;
+ (SOCSentryId *)captureException:(NSException *)exception withScope:(SOCSentryScope *)scope;
+ (SOCSentryId *)captureException:(NSException *)exception
                      withScopeBlock:(void (^)(SOCSentryScope *))block;
+ (SOCSentryId *)captureException:(NSException *)exception
                    attachAllThreads:(BOOL)attachAllThreads;

+ (SOCSentryId *)captureMessage:(NSString *)message;
+ (SOCSentryId *)captureMessage:(NSString *)message withScope:(SOCSentryScope *)scope;
+ (SOCSentryId *)captureMessage:(NSString *)message
                    withScopeBlock:(void (^)(SOCSentryScope *))block;
+ (SOCSentryId *)captureMessage:(NSString *)message attachAllThreads:(BOOL)attachAllThreads;

+ (void)captureFeedback:(SOCSentryFeedback *)feedback;

/// The user-feedback API; iOS only.
@property (class, nonatomic, readonly, strong) SOCSentryFeedbackAPI *feedback;

// MARK: Breadcrumbs / scope / user

+ (void)addBreadcrumb:(SOCSentryBreadcrumb *)crumb;
+ (void)configureScope:(void (^)(SOCSentryScope *))callback;
+ (void)setUser:(nullable SOCSentryUser *)user;

// MARK: Continuous profiling

+ (void)startProfiler;
+ (void)stopProfiler;

@end

NS_ASSUME_NONNULL_END
