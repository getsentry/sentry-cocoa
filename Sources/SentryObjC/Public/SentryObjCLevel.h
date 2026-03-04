#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Severity level of an event or breadcrumb.
 *
 * @see SentryEvent
 * @see SentryBreadcrumb
 */
typedef NS_ENUM(NSUInteger, SentryLevel) {
    kSentryLevelNone = 0,
    kSentryLevelDebug = 1,
    kSentryLevelInfo = 2,
    kSentryLevelWarning = 3,
    kSentryLevelError = 4,
    kSentryLevelFatal = 5
};

NS_ASSUME_NONNULL_END
