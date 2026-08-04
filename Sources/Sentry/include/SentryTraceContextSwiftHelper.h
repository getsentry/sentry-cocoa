#import "SentryOptionsObjC.h"
#import <Foundation/Foundation.h>

@class SentryBaggage;

NS_ASSUME_NONNULL_BEGIN

/**
 * Bridges private SentryTraceContext construction to Swift.
 *
 * In source-based SPM builds, SentryTraceContext is declared by SentryHeaders while its private
 * category is declared by _SentryPrivate. Swift does not merge an Objective-C category into a
 * class imported from another module, so the private initializer is unavailable to Swift. Keeping
 * the initializer call in Objective-C preserves the private API boundary across all build systems.
 */
@interface SentryTraceContextSwiftHelper : NSObject

+ (SentryBaggage *)baggageWithTraceId:(NSString *)traceId
                              options:(SentryOptionsObjC *)options
                             replayId:(nullable NSString *)replayId
    NS_SWIFT_NAME(baggage(traceId:options:replayId:));

@end

NS_ASSUME_NONNULL_END
