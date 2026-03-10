#import <Foundation/Foundation.h>

#import "SentryObjCMetricsApi.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal implementation of the metrics API protocol.
 *
 * This class delegates all metrics recording to the Swift layer via SentrySDKInternal.
 * Not exposed in public headers.
 */
@interface SentryObjCMetricsApiImpl : NSObject <SentryObjCMetricsApi>

@end

NS_ASSUME_NONNULL_END
