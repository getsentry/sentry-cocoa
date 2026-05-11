#import <Foundation/Foundation.h>

/**
 * Severity levels for structured logging.
 */
typedef NS_ENUM(NSInteger, SentryLogLevel) {
    SentryLogLevelTrace = 0,
    SentryLogLevelDebug,
    SentryLogLevelInfo,
    SentryLogLevelWarn,
    SentryLogLevelError,
    SentryLogLevelFatal
};
