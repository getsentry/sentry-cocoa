#import <Foundation/Foundation.h>

/// Severity of a Sentry event or breadcrumb. Raw values match the underlying
/// `SentryLevel` enum in the Sentry SDK.
typedef NS_ENUM(NSUInteger, SentryCompatLevel) {
    SentryCompatLevelNone = 0,
    SentryCompatLevelDebug = 1,
    SentryCompatLevelInfo = 2,
    SentryCompatLevelWarning = 3,
    SentryCompatLevelError = 4,
    SentryCompatLevelFatal = 5,
};
