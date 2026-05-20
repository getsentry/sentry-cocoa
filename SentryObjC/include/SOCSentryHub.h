#import <Foundation/Foundation.h>

@class SOCSentryClient;
@class SOCSentryScope;
@class SOCSentryEvent;
@class SOCSentryId;
@class SOCSentrySpan;
@class SOCSentryTransactionContext;
@class SOCSentryBreadcrumb;
@class SOCSentryFeedback;
@class SOCSentryUser;

NS_ASSUME_NONNULL_BEGIN

/// Central manager for SDK configuration, event capture, and scope management.
@interface SOCSentryHub : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithClient:(nullable SOCSentryClient *)client
                      andScope:(nullable SOCSentryScope *)scope;

- (void)startSession;
- (void)endSession;
- (void)endSessionWithTimestamp:(NSDate *)timestamp;

- (SOCSentryId *)captureEvent:(SOCSentryEvent *)event;
- (SOCSentryId *)captureEvent:(SOCSentryEvent *)event
                       withScope:(SOCSentryScope *)scope;

- (SOCSentrySpan *)startTransactionWithName:(NSString *)name
                                     operation:(NSString *)operation;
- (SOCSentrySpan *)startTransactionWithName:(NSString *)name
                                     operation:(NSString *)operation
                                   bindToScope:(BOOL)bindToScope;
- (SOCSentrySpan *)startTransactionWithContext:(SOCSentryTransactionContext *)transactionContext;
- (SOCSentrySpan *)startTransactionWithContext:(SOCSentryTransactionContext *)transactionContext
                                      bindToScope:(BOOL)bindToScope;
- (SOCSentrySpan *)startTransactionWithContext:(SOCSentryTransactionContext *)transactionContext
                                      bindToScope:(BOOL)bindToScope
                            customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;
- (SOCSentrySpan *)startTransactionWithContext:(SOCSentryTransactionContext *)transactionContext
                            customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

- (SOCSentryId *)captureError:(NSError *)error;
- (SOCSentryId *)captureError:(NSError *)error withScope:(SOCSentryScope *)scope;
- (SOCSentryId *)captureException:(NSException *)exception;
- (SOCSentryId *)captureException:(NSException *)exception withScope:(SOCSentryScope *)scope;
- (SOCSentryId *)captureMessage:(NSString *)message;
- (SOCSentryId *)captureMessage:(NSString *)message withScope:(SOCSentryScope *)scope;
- (void)captureFeedback:(SOCSentryFeedback *)feedback;

- (void)configureScope:(void (^)(SOCSentryScope *))callback;
- (void)addBreadcrumb:(SOCSentryBreadcrumb *)crumb;
- (nullable SOCSentryClient *)getClient;
@property (nonatomic, readonly, strong) SOCSentryScope *scope;
- (void)bindClient:(nullable SOCSentryClient *)client;
- (BOOL)hasIntegration:(NSString *)integrationName;
- (BOOL)isIntegrationInstalled:(Class)integrationClass;
- (void)setUser:(nullable SOCSentryUser *)user;
- (void)reportFullyDisplayed;
- (void)flush:(NSTimeInterval)timeout;
- (void)close;

@end

NS_ASSUME_NONNULL_END
