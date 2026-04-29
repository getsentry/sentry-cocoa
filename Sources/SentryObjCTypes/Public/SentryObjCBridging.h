#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

@class SentryOptions;
@class SentryUser;
@class SentryEvent;
@class SentryScope;
@class SentryBreadcrumb;
@class SentryFeedback;
@class SentryId;
@class SentryTransactionContext;
@class SentryLogger;
@class SentryObjCAttributeContent;
@protocol SentrySpan;

NS_ASSUME_NONNULL_BEGIN

/// Internal bridging contract between SentryObjC (pure ObjC) and SentryObjCBridge (Swift).
///
/// SentryObjC's `.m` files declare a class adopting this protocol so they can call into
/// the Swift bridge with typed parameters without importing `SentryObjCBridge-Swift.h`.
/// `SentrySwiftBridge` (in SentryObjCBridge) conforms to this protocol; the Swift
/// compiler verifies every required method is implemented, so the `.m`'s call sites and
/// the bridge's `@objc` emission cannot drift.
///
/// `NS_SWIFT_NAME` annotations on each method pin Swift's import name so it matches the
/// bridge's Swift signature exactly — without these, Swift's automatic ObjC→Swift
/// renaming (e.g., `sdkCaptureEvent:` → `sdkCapture(_:)`) would produce names the
/// bridge doesn't satisfy.
///
/// This protocol is internal to the SentryObjC SDK — consumers should not adopt it.
@protocol SentryObjCBridging <NSObject>

#pragma mark - SDK API

@property (class, nonatomic, readonly, nullable) id<SentrySpan> sdkSpan;
@property (class, nonatomic, readonly) BOOL sdkIsEnabled;
@property (class, nonatomic, readonly) BOOL sdkCrashedLastRun;
@property (class, nonatomic, readonly) NSInteger sdkLastRunStatus;
@property (class, nonatomic, readonly) BOOL sdkDetectedStartUpCrash;

+ (void)sdkStartWithOptions:(SentryOptions *)options NS_SWIFT_NAME(sdkStart(options:));
+ (void)sdkStartWithConfigureOptions:(void (^)(SentryOptions *options))configureOptions
    NS_SWIFT_NAME(sdkStart(configureOptions:));

+ (SentryId *)sdkCaptureEvent:(SentryEvent *)event NS_SWIFT_NAME(sdkCaptureEvent(_:));
+ (SentryId *)sdkCaptureEvent:(SentryEvent *)event
                    withScope:(SentryScope *)scope NS_SWIFT_NAME(sdkCaptureEvent(_:withScope:));
+ (SentryId *)sdkCaptureEvent:(SentryEvent *)event
               withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(sdkCaptureEvent(_:withScopeBlock:));
+ (SentryId *)sdkCaptureEvent:(SentryEvent *)event
             attachAllThreads:(BOOL)attachAllThreads
    NS_SWIFT_NAME(sdkCaptureEvent(_:attachAllThreads:));

+ (id<SentrySpan>)sdkStartTransactionWithName:(NSString *)name
                                    operation:(NSString *)operation
    NS_SWIFT_NAME(sdkStartTransaction(name:operation:));
+ (id<SentrySpan>)sdkStartTransactionWithName:(NSString *)name
                                    operation:(NSString *)operation
                                  bindToScope:(BOOL)bindToScope
    NS_SWIFT_NAME(sdkStartTransaction(name:operation:bindToScope:));
+ (id<SentrySpan>)sdkStartTransactionWithContext:(SentryTransactionContext *)transactionContext
    NS_SWIFT_NAME(sdkStartTransaction(transactionContext:));
+ (id<SentrySpan>)sdkStartTransactionWithContext:(SentryTransactionContext *)transactionContext
                                     bindToScope:(BOOL)bindToScope
    NS_SWIFT_NAME(sdkStartTransaction(transactionContext:bindToScope:));
+ (id<SentrySpan>)sdkStartTransactionWithContext:(SentryTransactionContext *)transactionContext
                           customSamplingContext:
                               (NSDictionary<NSString *, id> *)customSamplingContext
    NS_SWIFT_NAME(sdkStartTransaction(transactionContext:customSamplingContext:));
+ (id<SentrySpan>)sdkStartTransactionWithContext:(SentryTransactionContext *)transactionContext
                                     bindToScope:(BOOL)bindToScope
                           customSamplingContext:
                               (NSDictionary<NSString *, id> *)customSamplingContext
    NS_SWIFT_NAME(sdkStartTransaction(transactionContext:bindToScope:customSamplingContext:));

+ (SentryId *)sdkCaptureError:(NSError *)error NS_SWIFT_NAME(sdkCaptureError(_:));
+ (SentryId *)sdkCaptureError:(NSError *)error
                    withScope:(SentryScope *)scope NS_SWIFT_NAME(sdkCaptureError(_:withScope:));
+ (SentryId *)sdkCaptureError:(NSError *)error
               withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(sdkCaptureError(_:withScopeBlock:));
+ (SentryId *)sdkCaptureError:(NSError *)error
             attachAllThreads:(BOOL)attachAllThreads
    NS_SWIFT_NAME(sdkCaptureError(_:attachAllThreads:));

+ (SentryId *)sdkCaptureException:(NSException *)exception NS_SWIFT_NAME(sdkCaptureException(_:));
+ (SentryId *)sdkCaptureException:(NSException *)exception
                        withScope:(SentryScope *)scope
    NS_SWIFT_NAME(sdkCaptureException(_:withScope:));
+ (SentryId *)sdkCaptureException:(NSException *)exception
                   withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(sdkCaptureException(_:withScopeBlock:));
+ (SentryId *)sdkCaptureException:(NSException *)exception
                 attachAllThreads:(BOOL)attachAllThreads
    NS_SWIFT_NAME(sdkCaptureException(_:attachAllThreads:));

+ (SentryId *)sdkCaptureMessage:(NSString *)message NS_SWIFT_NAME(sdkCaptureMessage(_:));
+ (SentryId *)sdkCaptureMessage:(NSString *)message
                      withScope:(SentryScope *)scope NS_SWIFT_NAME(sdkCaptureMessage(_:withScope:));
+ (SentryId *)sdkCaptureMessage:(NSString *)message
                 withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(sdkCaptureMessage(_:withScopeBlock:));
+ (SentryId *)sdkCaptureMessage:(NSString *)message
               attachAllThreads:(BOOL)attachAllThreads
    NS_SWIFT_NAME(sdkCaptureMessage(_:attachAllThreads:));

+ (void)sdkCaptureFeedback:(SentryFeedback *)feedback NS_SWIFT_NAME(sdkCaptureFeedback(_:));
+ (void)sdkAddBreadcrumb:(SentryBreadcrumb *)crumb NS_SWIFT_NAME(sdkAddBreadcrumb(_:));
+ (void)sdkConfigureScope:(void (^)(SentryScope *scope))callback
    NS_SWIFT_NAME(sdkConfigureScope(_:));

+ (void)sdkSetUser:(nullable SentryUser *)user NS_SWIFT_NAME(sdkSetUser(_:));

+ (void)sdkStartSession;
+ (void)sdkEndSession;
+ (void)sdkCrash;
+ (void)sdkReportFullyDisplayed;
+ (void)sdkPauseAppHangTracking;
+ (void)sdkResumeAppHangTracking;
+ (void)sdkFlushWithTimeout:(NSTimeInterval)timeout NS_SWIFT_NAME(sdkFlush(timeout:));
+ (void)sdkClose;

#if !(TARGET_OS_WATCH || TARGET_OS_TV || TARGET_OS_VISION)
+ (void)sdkStartProfiler;
+ (void)sdkStopProfiler;
#endif

#pragma mark - Logger accessor

@property (class, nonatomic, readonly) SentryLogger *logger;

#pragma mark - Metrics API

+ (void)metricsCountWithKey:(NSString *)key
                      value:(NSUInteger)value
                 attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes
    NS_SWIFT_NAME(metricsCount(key:value:attributes:));
+ (void)metricsDistributionWithKey:(NSString *)key
                             value:(double)value
                              unit:(nullable NSString *)unit
                        attributes:
                            (NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes
    NS_SWIFT_NAME(metricsDistribution(key:value:unit:attributes:));
+ (void)metricsGaugeWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable NSString *)unit
                 attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes
    NS_SWIFT_NAME(metricsGauge(key:value:unit:attributes:));

@end

NS_ASSUME_NONNULL_END
