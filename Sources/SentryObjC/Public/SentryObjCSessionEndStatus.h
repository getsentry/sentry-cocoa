#import <Foundation/Foundation.h>

// According to https://develop.sentry.dev/sdk/telemetry/sessions/
// session has four terminal states: exited, unhandled, crashed, abnormal

// This enum must be kept in sync with SentrySessionEndStatus.h
typedef NS_ENUM(NSUInteger, SentryObjCSessionEndStatus) {
    /// The session exited normally. Handled errors may still have occurred.
    SentryObjCSessionEndStatusExited,
    /// The session ended because of a crash.
    SentryObjCSessionEndStatusCrashed,
    /// The session fate is unknown, for example power loss or killed by OS.
    SentryObjCSessionEndStatusAbnormal,
    /// The session ended because of an unhandled error that didn't terminate the process.
    SentryObjCSessionEndStatusUnhandled
};
