#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

@class SentryId;
@class SentrySpanId;
@class SentryObjCMetricValue;
@class SentryObjCAttributeContent;

NS_ASSUME_NONNULL_BEGIN

/**
 * ObjC wrapper for SentryMetric struct.
 *
 * @see SentryObjCMetricValue
 * @see SentryObjCAttributeContent
 */
@interface SentryObjCMetric : NSObject

@property (nonatomic, readonly) NSDate *timestamp;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) SentryId *traceId;
@property (nonatomic, readonly, nullable) SentrySpanId *spanId;
@property (nonatomic, readonly) SentryObjCMetricValue *value;
@property (nonatomic, readonly, nullable) NSString *unit;
@property (nonatomic, readonly) NSDictionary<NSString *, SentryObjCAttributeContent *> *attributes;

@end

NS_ASSUME_NONNULL_END
