#import "SentryDefines.h"
#import "SentryTraceContext.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

// Redeclare existing SDK selectors with module-safe types; implementations remain in the SDK.
@interface SentryTraceContext (TestAccess)
- (nullable instancetype)initWithScope:(SentryScope *)scope
                               options:(SENTRY_SWIFT_MIGRATION_ID(SentryOptions))options
    NS_SWIFT_NAME(init(testScope:testOptions:));
- (nullable instancetype)initWithTracer:(SentryTracer *)tracer
                                  scope:(nullable SentryScope *)scope
                                options:(SENTRY_SWIFT_MIGRATION_ID(SentryOptions))options
    NS_SWIFT_NAME(init(testTracer:scope:testOptions:));
- (instancetype)initWithTraceId:(SentryId *)traceId
                        options:(SENTRY_SWIFT_MIGRATION_ID(SentryOptions))options
                       replayId:(nullable NSString *)replayId
    NS_SWIFT_NAME(init(testTrace:testOptions:replayId:));
@end

NS_ASSUME_NONNULL_END
