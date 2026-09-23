#import "SentryClient+Telemetry.h"
#import "SentryLogC.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryClientInternal (Telemetry)

- (void)_swiftCaptureLog:(NSObject *)log withScope:(SentryScope *)scope
{
    SentryScope *cs = [self.currentScopeStorage scope];
    [self _swiftCaptureLog:log withScope:scope currentScope:cs];
}

- (void)_swiftCaptureLog:(NSObject *)log
               withScope:(SentryScope *)scope
            currentScope:(nullable SentryScope *)currentScope
{
    if ([self isDisabled]) {
        [self logDisabledMessage];
        return;
    }

    if (![log isKindOfClass:[SentryLog class]]) {
        return;
    }

    // Custom attribute precedence: caller > current scope > global scope. Trace correlation,
    // user, and the other reserved attributes come from the global scope only.
    SentryLog *enrichedLog = [self.logScopeApplier applyScope:scope
                                                 currentScope:currentScope
                                                        toLog:(SentryLog *)log];
    SentryLog *logToSend = enrichedLog;

    if (self.options.beforeSendLog != nil) {
        logToSend = self.options.beforeSendLog(enrichedLog);
        if (logToSend == nil) {
            SENTRY_LOG_DEBUG(@"Log dropped by beforeSendLog callback.");
            [self recordDroppedLogInClientReport:enrichedLog];
            return;
        }
    }

    [self.telemetryProcessor addLog:logToSend];
}

- (void)recordDroppedLogInClientReport:(SentryLog *)log
{
    [self recordDroppedItemInClientReportWithItemCategory:SentryDataCategoryLogItem
                                             byteCategory:SentryDataCategoryLogByte
                                           byteCountBlock:^NSUInteger {
                                               return [SentryLogClientReport
                                                   serializedByteCountForLog:log];
                                           }];
}

- (void)recordDroppedTraceMetricInClientReport:(SentryMetricObjC *)metric
{
    [self recordDroppedItemInClientReportWithItemCategory:SentryDataCategoryTraceMetric
                                             byteCategory:SentryDataCategoryTraceMetricByte
                                           byteCountBlock:^NSUInteger {
                                               return [metric serializedByteCount];
                                           }];
}

- (void)recordDroppedItemInClientReportWithItemCategory:(SentryDataCategory)itemCategory
                                           byteCategory:(SentryDataCategory)byteCategory
                                         byteCountBlock:(NSUInteger (^)(void))byteCountBlock
{
    // Offload to a background queue: serializing the item to determine its byte size is too
    // expensive to run inline in a beforeSend callback, which runs on the calling thread and must
    // stay fast.
    __weak SentryClientInternal *weakSelf = self;
    [self.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        SentryClientInternal *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        NSUInteger byteCount = byteCountBlock();
        [strongSelf recordLostEvent:itemCategory reason:SentryDiscardReasonBeforeSend];
        [strongSelf recordLostEvent:byteCategory
                             reason:SentryDiscardReasonBeforeSend
                           quantity:byteCount];
    }];
}

- (id)getTelemetryProcessor
{
    return self.telemetryProcessor;
}

@end

NS_ASSUME_NONNULL_END
