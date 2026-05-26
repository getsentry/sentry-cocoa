#import "SentryObjCDefines.h"
#import "SentryObjCFeedbackSource.h"
#import "SentryObjCLastRunStatus.h"
#import <Foundation/Foundation.h>

@class SentryObjCAttachment;
@class SentryObjCBreadcrumb;
@class SentryObjCEvent;
@class SentryObjCFeedbackApi;
@class SentryObjCId;
@class SentryObjCLogger;
@class SentryObjCOptions;
@class SentryObjCReplayApi;
@class SentryObjCScope;
@class SentryObjCSpan;
@class SentryObjCTransactionContext;
@class SentryObjCUser;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCSDK : NSObject

@property (class, nonatomic, readonly, nullable) SentryObjCSpan *span;
@property (class, nonatomic, readonly) BOOL isEnabled;
@property (class, nonatomic, readonly) SentryObjCLogger *logger;
@property (class, nonatomic, readonly) SentryObjCLastRunStatus lastRunStatus;
@property (class, nonatomic, readonly) BOOL detectedStartUpCrash;
@property (class, nonatomic, readonly) BOOL crashedLastRun
    __attribute__((deprecated("Use lastRunStatus instead.")));

#if SENTRY_OBJC_REPLAY_SUPPORTED
@property (class, nonatomic, readonly) SentryObjCReplayApi *replay;
#endif

#if TARGET_OS_IOS && SENTRY_OBJC_HAS_UIKIT
@property (class, nonatomic, readonly) SentryObjCFeedbackApi *feedback;
#endif

+ (void)startWithOptions:(SentryObjCOptions *)options;
+ (void)startWithConfigureOptions:(void (^)(SentryObjCOptions *))configureOptions;

+ (SentryObjCId *)captureEvent:(SentryObjCEvent *)event;
+ (SentryObjCId *)captureEvent:(SentryObjCEvent *)event withScope:(SentryObjCScope *)scope;
+ (SentryObjCId *)captureEvent:(SentryObjCEvent *)event
                withScopeBlock:(void (^)(SentryObjCScope *))block;
+ (SentryObjCId *)captureEvent:(SentryObjCEvent *)event attachAllThreads:(BOOL)attachAllThreads;

+ (SentryObjCSpan *)startTransactionWithName:(NSString *)name operation:(NSString *)operation;
+ (SentryObjCSpan *)startTransactionWithName:(NSString *)name
                                   operation:(NSString *)operation
                                 bindToScope:(BOOL)bindToScope;
+ (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext;
+ (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                                    bindToScope:(BOOL)bindToScope;
+ (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                                    bindToScope:(BOOL)bindToScope
                          customSamplingContext:
                              (NSDictionary<NSString *, id> *)customSamplingContext;
+ (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                          customSamplingContext:
                              (NSDictionary<NSString *, id> *)customSamplingContext;

+ (SentryObjCId *)captureError:(NSError *)error;
+ (SentryObjCId *)captureError:(NSError *)error withScope:(SentryObjCScope *)scope;
+ (SentryObjCId *)captureError:(NSError *)error withScopeBlock:(void (^)(SentryObjCScope *))block;
+ (SentryObjCId *)captureError:(NSError *)error attachAllThreads:(BOOL)attachAllThreads;

+ (SentryObjCId *)captureException:(NSException *)exception;
+ (SentryObjCId *)captureException:(NSException *)exception withScope:(SentryObjCScope *)scope;
+ (SentryObjCId *)captureException:(NSException *)exception
                    withScopeBlock:(void (^)(SentryObjCScope *))block;
+ (SentryObjCId *)captureException:(NSException *)exception attachAllThreads:(BOOL)attachAllThreads;

+ (SentryObjCId *)captureMessage:(NSString *)message;
+ (SentryObjCId *)captureMessage:(NSString *)message withScope:(SentryObjCScope *)scope;
+ (SentryObjCId *)captureMessage:(NSString *)message
                  withScopeBlock:(void (^)(SentryObjCScope *))block;
+ (SentryObjCId *)captureMessage:(NSString *)message attachAllThreads:(BOOL)attachAllThreads;

+ (void)captureFeedbackWithMessage:(NSString *)message
                              name:(nullable NSString *)name
                             email:(nullable NSString *)email
                            source:(SentryObjCFeedbackSource)source
                 associatedEventId:(nullable SentryObjCId *)associatedEventId
                       attachments:(nullable NSArray<SentryObjCAttachment *> *)attachments;

+ (void)addBreadcrumb:(SentryObjCBreadcrumb *)crumb;
+ (void)configureScope:(void (^)(SentryObjCScope *))callback;
+ (void)setUser:(nullable SentryObjCUser *)user;
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
