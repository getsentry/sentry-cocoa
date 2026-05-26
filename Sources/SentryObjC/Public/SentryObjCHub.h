#import <Foundation/Foundation.h>

@class SentryObjCClient;
@class SentryObjCEvent;
@class SentryObjCScope;
@class SentryObjCId;
@class SentryObjCBreadcrumb;
@class SentryObjCUser;
@class SentryObjCFeedback;
@class SentryObjCSpan;
@class SentryObjCTransactionContext;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCHub : NSObject

- (instancetype)initWithClient:(SentryObjCClient *_Nullable)client
                      andScope:(SentryObjCScope *_Nullable)scope;

- (void)startSession;
- (void)endSession;
- (void)endSessionWithTimestamp:(NSDate *)timestamp;

- (SentryObjCId *)captureEvent:(SentryObjCEvent *)event NS_SWIFT_NAME(capture(event:));
- (SentryObjCId *)captureEvent:(SentryObjCEvent *)event
                     withScope:(SentryObjCScope *)scope NS_SWIFT_NAME(capture(event:scope:));

- (SentryObjCId *)captureError:(NSError *)error NS_SWIFT_NAME(capture(error:));
- (SentryObjCId *)captureError:(NSError *)error
                     withScope:(SentryObjCScope *)scope NS_SWIFT_NAME(capture(error:scope:));

- (SentryObjCId *)captureException:(NSException *)exception NS_SWIFT_NAME(capture(exception:));
- (SentryObjCId *)captureException:(NSException *)exception
                         withScope:(SentryObjCScope *)scope
    NS_SWIFT_NAME(capture(exception:scope:));

- (SentryObjCId *)captureMessage:(NSString *)message NS_SWIFT_NAME(capture(message:));
- (SentryObjCId *)captureMessage:(NSString *)message
                       withScope:(SentryObjCScope *)scope NS_SWIFT_NAME(capture(message:scope:));

- (void)captureFeedback:(SentryObjCFeedback *)feedback NS_SWIFT_NAME(capture(feedback:));

- (SentryObjCSpan *)startTransactionWithName:(NSString *)name operation:(NSString *)operation;
- (SentryObjCSpan *)startTransactionWithName:(NSString *)name
                                   operation:(NSString *)operation
                                 bindToScope:(BOOL)bindToScope;
- (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext;
- (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                                    bindToScope:(BOOL)bindToScope;
- (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                                    bindToScope:(BOOL)bindToScope
                          customSamplingContext:
                              (NSDictionary<NSString *, id> *)customSamplingContext;
- (SentryObjCSpan *)startTransactionWithContext:(SentryObjCTransactionContext *)transactionContext
                          customSamplingContext:
                              (NSDictionary<NSString *, id> *)customSamplingContext;

- (void)configureScope:(void (^)(SentryObjCScope *))callback;
- (void)addBreadcrumb:(SentryObjCBreadcrumb *)crumb;

- (SentryObjCClient *_Nullable)getClient;

@property (nonatomic, readonly, strong) SentryObjCScope *scope;

- (void)bindClient:(SentryObjCClient *_Nullable)client;

- (BOOL)hasIntegration:(NSString *)integrationName;
- (BOOL)isIntegrationInstalled:(Class)integrationClass;

- (void)setUser:(SentryObjCUser *_Nullable)user;
- (void)reportFullyDisplayed;

- (void)flush:(NSTimeInterval)timeout;
- (void)close;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
