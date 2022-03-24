#import <Foundation/Foundation.h>

/**
 * The data category rate limits: https://develop.sentry.dev/sdk/rate-limiting/#definitions and
 * client reports: https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload. Be aware
 * that these categories are different from the envelope item types.
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
