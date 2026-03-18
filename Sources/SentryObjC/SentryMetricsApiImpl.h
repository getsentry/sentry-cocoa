#import <Foundation/Foundation.h>

#import "SentryMetricsApi.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal implementation of the metrics API protocol.
 *
 * This class delegates all metrics recording to the Swift layer via SentrySDKInternal.
 * Not exposed in public headers.
 */
@interface SentryMetricsApiImpl : NSObject <SentryMetricsApi>

@end

NS_ASSUME_NONNULL_END
