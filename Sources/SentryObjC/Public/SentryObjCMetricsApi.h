#import <Foundation/Foundation.h>

@class SentryObjCAttributeContent;
@class SentryObjCUnit;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCMetricsApi : NSObject

- (void)countWithKey:(NSString *)key
               value:(NSUInteger)value
          attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes;
- (void)countWithKey:(NSString *)key value:(NSUInteger)value;
- (void)countWithKey:(NSString *)key;

- (void)distributionWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable SentryObjCUnit *)unit
                 attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes;
- (void)distributionWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable SentryObjCUnit *)unit;
- (void)distributionWithKey:(NSString *)key value:(double)value;

- (void)gaugeWithKey:(NSString *)key
               value:(double)value
                unit:(nullable SentryObjCUnit *)unit
          attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes;
- (void)gaugeWithKey:(NSString *)key value:(double)value unit:(nullable SentryObjCUnit *)unit;
- (void)gaugeWithKey:(NSString *)key value:(double)value;

@end

NS_ASSUME_NONNULL_END
