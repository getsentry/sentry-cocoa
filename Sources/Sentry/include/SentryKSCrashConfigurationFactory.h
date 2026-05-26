#ifndef SentryKSCrashConfigurationFactory_h
#define SentryKSCrashConfigurationFactory_h

#import <Foundation/Foundation.h>
@import KSCrashRecording;

NS_ASSUME_NONNULL_BEGIN

/**
 * Factory for creating KSCrashConfiguration objects with Sentry-specific
 * defaults pre-wired.
 *
 * The callback properties on @c KSCrashConfiguration (e.g. @c isWritingReportCallback,
 * @c willWriteReportCallback) are @c NS_SWIFT_UNAVAILABLE and must be set from ObjC.
 * This factory provides a single place where those callbacks are assigned together
 * with the other installation parameters.
 */
@interface SentryKSCrashConfigurationFactory : NSObject

/**
 * Creates a fully configured @c KSCrashConfiguration with Sentry's
 * @c isWritingReportCallback pre-wired.
 *
 * @param installPath   Base path for KSCrash installation files.
 * @param monitors      Crash monitor types to enable.
 * @param sigterm       Whether to enable SIGTERM monitoring.
 * @param cxxSwap       Whether to enable @c __cxa_throw swap for C++ exceptions.
 * @return Configured @c KSCrashConfiguration ready for installation.
 */
+ (KSCrashConfiguration *)configurationWithInstallPath:(NSString *)installPath
                                              monitors:(KSCrashMonitorType)monitors
                               enableSigTermMonitoring:(BOOL)sigterm
                                    enableSwapCxaThrow:(BOOL)cxxSwap;

/**
 * Creates a fully configured @c KSCrashConfiguration with Sentry's
 * @c isWritingReportCallback pre-wired and an optional transaction-persisting
 * @c willWriteReportCallback.
 *
 * When @c persistTracesOnCrash is @c YES, the configuration's
 * @c willWriteReportCallback is set to @c sentry_kscrash_willWriteReportCallback,
 * which calls @c sentry_finishAndSaveTransaction() before the report is written.
 * Because @c KSCrashWillWriteReportCallback is @c NS_SWIFT_UNAVAILABLE, the boolean
 * flag lets Swift callers opt in without touching the C function-pointer type.
 *
 * @param installPath              Base path for KSCrash installation files.
 * @param monitors                 Crash monitor types to enable.
 * @param sigterm                  Whether to enable SIGTERM monitoring.
 * @param cxxSwap                  Whether to enable @c __cxa_throw swap for C++ exceptions.
 * @param persistTracesOnCrash     When @c YES, register a @c willWriteReportCallback that
 *                                 finishes and saves the active transaction at crash time.
 * @return Configured @c KSCrashConfiguration ready for installation.
 */
+ (KSCrashConfiguration *)configurationWithInstallPath:(NSString *)installPath
                                              monitors:(KSCrashMonitorType)monitors
                               enableSigTermMonitoring:(BOOL)sigterm
                                    enableSwapCxaThrow:(BOOL)cxxSwap
                                  persistTracesOnCrash:(BOOL)persistTracesOnCrash;

@end

NS_ASSUME_NONNULL_END

#endif /* SentryKSCrashConfigurationFactory_h */
