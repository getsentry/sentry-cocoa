#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "SentryOptions.h"

#if __has_include(<SentryObjCTypes/SentryObjCMetric.h>)
#    import <SentryObjCTypes/SentryObjCMetric.h>
#else
#    import "SentryObjCMetric.h"
#endif

static const void *kBeforeSendMetricKey = &kBeforeSendMetricKey;

@implementation SentryOptions (ObjCBridge)

- (void)setBeforeSendMetric:(SentryBeforeSendMetricCallback)block
{
    objc_setAssociatedObject(self, kBeforeSendMetricKey, block, OBJC_ASSOCIATION_COPY);
}

- (SentryBeforeSendMetricCallback)beforeSendMetric
{
    return objc_getAssociatedObject(self, kBeforeSendMetricKey);
}

@end
