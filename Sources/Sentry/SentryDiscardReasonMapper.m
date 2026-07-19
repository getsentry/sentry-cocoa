#import "SentryDiscardReasonMapper.h"
#import "SentrySwift.h"

NSString *const kSentryDiscardReasonNameBeforeSend = @"before_send";
NSString *const kSentryDiscardReasonNameEventProcessor = @"event_processor";
NSString *const kSentryDiscardReasonNameSampleRate = @"sample_rate";
NSString *const kSentryDiscardReasonNameNetworkError = @"network_error";
NSString *const kSentryDiscardReasonNameQueueOverflow = @"queue_overflow";
NSString *const kSentryDiscardReasonNameCacheOverflow = @"cache_overflow";
NSString *const kSentryDiscardReasonNameRateLimitBackoff = @"ratelimit_backoff";
NSString *const kSentryDiscardReasonNameInsufficientData = @"insufficient_data";
NSString *const kSentryDiscardReasonNameSendError = @"send_error";

NSString *_Nonnull nameForSentryDiscardReason(SentryDiscardReason reason)
{
    switch (reason) {
    case SentryDiscardReasonBeforeSend:
        return kSentryDiscardReasonNameBeforeSend;
    case SentryDiscardReasonEventProcessor:
        return kSentryDiscardReasonNameEventProcessor;
    case SentryDiscardReasonSampleRate:
        return kSentryDiscardReasonNameSampleRate;
    case SentryDiscardReasonNetworkError:
        return kSentryDiscardReasonNameNetworkError;
    case SentryDiscardReasonQueueOverflow:
        return kSentryDiscardReasonNameQueueOverflow;
    case SentryDiscardReasonCacheOverflow:
        return kSentryDiscardReasonNameCacheOverflow;
    case SentryDiscardReasonRateLimitBackoff:
        return kSentryDiscardReasonNameRateLimitBackoff;
    case SentryDiscardReasonInsufficientData:
        return kSentryDiscardReasonNameInsufficientData;
    case SentryDiscardReasonSendError:
        return kSentryDiscardReasonNameSendError;
    }
}
