#import <Foundation/Foundation.h>

/**
 * The data category used for envelopes: https://develop.sentry.dev/sdk/envelopes/#data-model, rate
 * limits: https://develop.sentry.dev/sdk/rate-limiting/#definitions and client reports:
 * https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload.
 */
typedef NS_ENUM(NSUInteger, SentryDataCategory) {
    kSentryDataCategoryAll,
    kSentryDataCategoryDefault,
    kSentryDataCategoryError,
    kSentryDataCategorySession,
    kSentryDataCategoryTransaction,
    kSentryDataCategoryAttachment,
    kSentryDataCategoryUnknown
};
