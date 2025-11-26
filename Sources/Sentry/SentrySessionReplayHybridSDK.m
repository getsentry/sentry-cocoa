#import "SentrySessionReplayHybridSDK.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryLogC.h"
#    import "SentrySwift.h"

@implementation SentrySessionReplayHybridSDK

+ (id<SentryRRWebEvent>)createBreadcrumbwithTimestamp:(NSDate *)timestamp
                                             category:(NSString *)category
                                              message:(nullable NSString *)message
                                                level:(SentryLevel)level
                                                 data:(nullable NSDictionary<NSString *, id> *)data
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Creating breadcrumb with timestamp: %@, category: %@, "
                     @"message: %@, level: %lu, data: %@",
        timestamp, category, message, level, data);
    return [[SentryRRWebBreadcrumbEvent alloc] initWithTimestamp:timestamp
                                                        category:category
                                                         message:message
                                                           level:level
                                                            data:data];
}

+ (id<SentryRRWebEvent>)createNetworkBreadcrumbWithTimestamp:(NSDate *)timestamp
                                                endTimestamp:(NSDate *)endTimestamp
                                                   operation:(NSString *)operation
                                                 description:(NSString *)description
                                                        data:(NSDictionary<NSString *, id> *)data
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Creating network breadcrumb with timestamp: %@, "
                     @"endTimestamp: %@, operation: %@, description: %@, data: %@",
        timestamp, endTimestamp, operation, description, data);
    return [[SentryRRWebSpanEvent alloc] initWithTimestamp:timestamp
                                              endTimestamp:endTimestamp
                                                 operation:operation
                                               description:description
                                                      data:data];
}

+ (id<SentryReplayBreadcrumbConverter>)createDefaultBreadcrumbConverter
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Creating default breadcrumb converter");
    return [[SentrySRDefaultBreadcrumbConverter alloc] init];
}

@end

#endif
