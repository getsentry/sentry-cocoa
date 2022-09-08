#import <Foundation/Foundation.h>

/**
 * A reason that defines why events were lost, see
 * https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload.
 */
typedef NS_ENUM(NSUInteger, SentryDiscardReason) {
    kSentryDiscardReasonBeforeSend = 0,
    kSentryDiscardReasonEventProcessor = 1,
    kSentryDiscardReasonSampleRate = 2,
    kSentryDiscardReasonNetworkError = 3,
    kSentryDiscardReasonQueueOverflow = 4,
    kSentryDiscardReasonCacheOverflow = 5,
    kSentryDiscardReasonRateLimitBackoff = 6
};
