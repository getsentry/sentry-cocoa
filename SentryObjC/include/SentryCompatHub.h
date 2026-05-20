#import <Foundation/Foundation.h>

@class SentryCompatClient;
@class SentryCompatScope;
@class SentryCompatEvent;
@class SentryCompatId;
@class SentryCompatSpan;
@class SentryCompatTransactionContext;
@class SentryCompatBreadcrumb;
@class SentryCompatFeedback;
@class SentryCompatUser;

NS_ASSUME_NONNULL_BEGIN

/// Central manager for SDK configuration, event capture, and scope management.
@interface SentryCompatHub : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithClient:(nullable SentryCompatClient *)client
                      andScope:(nullable SentryCompatScope *)scope;

- (void)startSession;
- (void)endSession;
- (void)endSessionWithTimestamp:(NSDate *)timestamp;

- (SentryCompatId *)captureEvent:(SentryCompatEvent *)event;
- (SentryCompatId *)captureEvent:(SentryCompatEvent *)event
                       withScope:(SentryCompatScope *)scope;

- (SentryCompatSpan *)startTransactionWithName:(NSString *)name
                                     operation:(NSString *)operation;
- (SentryCompatSpan *)startTransactionWithName:(NSString *)name
                                     operation:(NSString *)operation
                                   bindToScope:(BOOL)bindToScope;
- (SentryCompatSpan *)startTransactionWithContext:(SentryCompatTransactionContext *)transactionContext;
- (SentryCompatSpan *)startTransactionWithContext:(SentryCompatTransactionContext *)transactionContext
                                      bindToScope:(BOOL)bindToScope;
- (SentryCompatSpan *)startTransactionWithContext:(SentryCompatTransactionContext *)transactionContext
                                      bindToScope:(BOOL)bindToScope
                            customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;
- (SentryCompatSpan *)startTransactionWithContext:(SentryCompatTransactionContext *)transactionContext
                            customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

- (SentryCompatId *)captureError:(NSError *)error;
- (SentryCompatId *)captureError:(NSError *)error withScope:(SentryCompatScope *)scope;
- (SentryCompatId *)captureException:(NSException *)exception;
- (SentryCompatId *)captureException:(NSException *)exception withScope:(SentryCompatScope *)scope;
- (SentryCompatId *)captureMessage:(NSString *)message;
- (SentryCompatId *)captureMessage:(NSString *)message withScope:(SentryCompatScope *)scope;
- (void)captureFeedback:(SentryCompatFeedback *)feedback;

- (void)configureScope:(void (^)(SentryCompatScope *))callback;
- (void)addBreadcrumb:(SentryCompatBreadcrumb *)crumb;
- (nullable SentryCompatClient *)getClient;
@property (nonatomic, readonly, strong) SentryCompatScope *scope;
- (void)bindClient:(nullable SentryCompatClient *)client;
- (BOOL)hasIntegration:(NSString *)integrationName;
- (BOOL)isIntegrationInstalled:(Class)integrationClass;
- (void)setUser:(nullable SentryCompatUser *)user;
- (void)reportFullyDisplayed;
- (void)flush:(NSTimeInterval)timeout;
- (void)close;

@end

NS_ASSUME_NONNULL_END
