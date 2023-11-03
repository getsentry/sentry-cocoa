#import <Foundation/Foundation.h>

@class SentryId, SentrySpanId, SentryTraceContext, SentryTraceHeader, SentryOptions, SentryScope;

NS_ASSUME_NONNULL_BEGIN

@interface SentryPropagationContext : NSObject

@property (nonatomic, strong) SentryId *traceId;
@property (nonatomic, strong) SentrySpanId *spanId;
@property (nonatomic, readonly) SentryTraceHeader *traceHeader;

- (NSDictionary<NSString *, NSString *> *)traceContextForEvent;

/**
 * We need to pass in the options and the user segment instead of retrieving them from the static
 * API cause, for example, the SentryClient can have multiple instances with different options and
 * scopes running and in that scenario we need can't retrieve these values from the static API.
 *
 *  @param options The current active options.
 *  @param userSegment You can retrieve this usually from the `scope.userObject.segment`.
 */
- (SentryTraceContext *)getTraceContext:(SentryOptions *)options
                            userSegment:(nullable NSString *)userSegment
    NS_SWIFT_NAME(getTraceContext(options:userSegment:));

@end

NS_ASSUME_NONNULL_END
