#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

@class SentryBreadcrumb;
@class SentryEvent;
@class SentryId;
@class SentryOptions;
@class SentryScope;
@class SentryTransactionContext;
@class SentryFeedback;
@class SentryUser;
@protocol SentrySpan;

#if SENTRY_OBJC_REPLAY_SUPPORTED
@class SentryReplayApi;
#endif

@class SentryLogger;

NS_ASSUME_NONNULL_BEGIN

/**
 * Main entry point for the Sentry SDK.
 *
 * @see SentryOptions
 * @see SentryScope
 */
@interface SentrySDK : NSObject

SENTRY_NO_INIT

+ (nullable id<SentrySpan>)span;
+ (BOOL)isEnabled;

#if SENTRY_OBJC_REPLAY_SUPPORTED
+ (SentryReplayApi *)replay;
#endif

+ (SentryLogger *)logger;

+ (void)startWithOptions:(SentryOptions *)options;
+ (void)startWithConfigureOptions:(void (^)(SentryOptions *options))configureOptions;

+ (SentryId *)captureEvent:(SentryEvent *)event;
+ (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope;
+ (SentryId *)captureEvent:(SentryEvent *)event withScopeBlock:(void (^)(SentryScope *scope))block;

+ (id<SentrySpan>)startTransactionWithName:(NSString *)name operation:(NSString *)operation;
+ (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                 operation:(NSString *)operation
                               bindToScope:(BOOL)bindToScope;
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext;
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope;
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

+ (SentryId *)captureError:(NSError *)error;
+ (SentryId *)captureError:(NSError *)error withScope:(SentryScope *)scope;
+ (SentryId *)captureError:(NSError *)error withScopeBlock:(void (^)(SentryScope *scope))block;

+ (SentryId *)captureException:(NSException *)exception;
+ (SentryId *)captureException:(NSException *)exception withScope:(SentryScope *)scope;
+ (SentryId *)captureException:(NSException *)exception
                withScopeBlock:(void (^)(SentryScope *scope))block;

+ (SentryId *)captureMessage:(NSString *)message;
+ (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope;
+ (SentryId *)captureMessage:(NSString *)message withScopeBlock:(void (^)(SentryScope *scope))block;

+ (void)captureFeedback:(SentryFeedback *)feedback;

+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb;
+ (void)configureScope:(void (^)(SentryScope *scope))callback;

+ (BOOL)crashedLastRun;
+ (BOOL)detectedStartUpCrash;

+ (void)setUser:(nullable SentryUser *)user;

+ (void)startSession;
+ (void)endSession;

+ (void)crash;
+ (void)reportFullyDisplayed;

+ (void)pauseAppHangTracking;
+ (void)resumeAppHangTracking;

+ (void)flush:(NSTimeInterval)timeout;
+ (void)close;

#if !(TARGET_OS_WATCH || TARGET_OS_TV || TARGET_OS_VISION)
+ (void)startProfiler;
+ (void)stopProfiler;
#endif

@end

NS_ASSUME_NONNULL_END
