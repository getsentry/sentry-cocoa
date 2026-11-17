#import <Foundation/Foundation.h>

// According to https://develop.sentry.dev/sdk/telemetry/sessions/
// session has four terminal states: exited, unhandled, crashed, abnormal

// This enum must be kept in sync with SentryObjCSessionEndStatus.h
typedef NS_ENUM(NSUInteger, SentrySessionEndStatus) {
    /// The session exited normally. Handled errors may still have occurred.
    kSentrySessionEndStatusExited,
    /// The session ended because of a crash.
    kSentrySessionEndStatusCrashed,
    /// The session fate is unknown, for example power loss or killed by OS.
    kSentrySessionEndStatusAbnormal,
    /// The session ended because of an unhandled error that didn't terminate the process.
    kSentrySessionEndStatusUnhandled
};
