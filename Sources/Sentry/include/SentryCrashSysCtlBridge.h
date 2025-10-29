#import "SentryDefines.h"
#include <sys/sysctl.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Bridge header to expose minimal sysctl C functions to Swift.
 * These should ONLY be used in SentrySysctl.swift where they are protected by SwiftLint rules.
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Get a timeval via sysctl.
 * @warning Do not use KERN_BOOTTIME directly - see
 * https://github.com/getsentry/sentry-cocoa/issues/6233
 */
struct timeval sentrycrashsysctl_timeval(int major_cmd, int minor_cmd);

/**
 * Get the process start time.
 */
struct timeval sentrycrashsysctl_currentProcessStartTime(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
