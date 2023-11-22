#import "SentryCrash.h"
#import "SentryDefines.h"

@class SentryInAppLogic, SentryCrashWrapper, SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashReportSink : SENTRY_BASE_OBJECT <SentryCrashReportFilter>
SENTRY_NO_INIT

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                      crashWrapper:(SentryCrashWrapper *)crashWrapper
                     dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue;

@end

NS_ASSUME_NONNULL_END
