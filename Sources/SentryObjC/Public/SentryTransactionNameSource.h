#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Describes the source of the transaction name.
 *
 * @see SentryTransactionContext
 */
typedef NS_ENUM(NSInteger, SentryTransactionNameSource) {
    /** The name was set manually by the user. */
    kSentryTransactionNameSourceCustom = 0,

    /** The name was derived from the request URL. */
    kSentryTransactionNameSourceUrl,

    /** The name was derived from a routing framework. */
    kSentryTransactionNameSourceRoute,

    /** The name was derived from a UI view or screen. */
    kSentryTransactionNameSourceView,

    /** The name was derived from a UI component. */
    kSentryTransactionNameSourceComponent,

    /** The name was derived from a background task. */
    kSentryTransactionNameSourceTask,
};

NS_ASSUME_NONNULL_END
