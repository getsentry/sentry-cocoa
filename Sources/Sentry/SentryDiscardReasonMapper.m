#import "SentryDiscardReasonMapper.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryDiscardReasonMapper

+ (SentryDiscardReason)mapStringToReason:(NSString *)value
{
    SentryDiscardReason reason = kSentryDiscardReasonBeforeSend;

    for (int i = 0; i <= kSentryDiscardReasonRateLimitBackoff; i++) {
        if ([value isEqualToString:SentryDiscardReasonNames[i]]) {
            return [SentryDiscardReasonMapper mapIntegerToReason:i];
        }
    }

    return reason;
}

+ (SentryDiscardReason)mapIntegerToReason:(NSUInteger)value
{
    SentryDiscardReason reason = kSentryDiscardReasonBeforeSend;

    if (value <= kSentryDiscardReasonRateLimitBackoff) {
        reason = (SentryDiscardReason)value;
    }

    return reason;
}

@end

NS_ASSUME_NONNULL_END
