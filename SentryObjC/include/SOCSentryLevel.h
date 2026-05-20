#import <Foundation/Foundation.h>

/// Severity of a Sentry event or breadcrumb. Raw values match the underlying
/// `SentryLevel` enum in the Sentry SDK.
typedef NS_ENUM(NSUInteger, SOCSentryLevel) {
    SOCSentryLevelNone = 0,
    SOCSentryLevelDebug = 1,
    SOCSentryLevelInfo = 2,
    SOCSentryLevelWarning = 3,
    SOCSentryLevelError = 4,
    SOCSentryLevelFatal = 5,
};
