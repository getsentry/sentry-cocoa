#import "SentryAutoSpanTransactionCarrierStarter.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import <SentrySpanOperations.h>
#import <SentryTraceOrigins.h>
#import <SentryTracer.h>
#import <SentryTransactionContext+Private.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAutoSpanTransactionCarrierStarter ()

@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, assign) NSTimeInterval idleTimeout;

@end

@implementation SentryAutoSpanTransactionCarrierStarter

- (instancetype)initWithDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                                 idleTimeout:(NSTimeInterval)idleTimeout
{
    if (self = [super init]) {
        self.dispatchQueueWrapper = dispatchQueueWrapper;
        self.idleTimeout = idleTimeout;
    }
    return self;
}

+ (BOOL)isCarrierTransaction:(NSString *)operation
{
    if ([operation isEqualToString:SentrySpanOperationCarrierTransaction]) {
        return YES;
    }
    return NO;
}

- (void)startSpan:(SentrySpanCallback)callback
{
    [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        if (span == nil) {
            SENTRY_LOG_DEBUG(@"Creating carrier transaction.");
            SentryTransactionContext *context =
                [[SentryTransactionContext alloc] initWithName:@"CarrierTransaction"
                                                    nameSource:kSentryTransactionNameSourceCarrier
                                                     operation:SentrySpanOperationCarrierTransaction
                                                        origin:SentryTraceOriginCarrierTransaction];

            span = [SentrySDK.currentHub
                startTransactionWithContext:context
                                bindToScope:YES
                      customSamplingContext:@{}
                              configuration:[SentryTracerConfiguration configurationWithBlock:^(
                                                SentryTracerConfiguration *config) {
                                  config.idleTimeout = self.idleTimeout;
                                  config.waitForChildren = YES;
                                  config.dispatchQueueWrapper = self.dispatchQueueWrapper;
                              }]];
        }

        callback(span);
    }];
}

@end

NS_ASSUME_NONNULL_END
