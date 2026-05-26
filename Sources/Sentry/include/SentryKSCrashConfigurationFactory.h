#ifndef SentryKSCrashConfigurationFactory_h
#define SentryKSCrashConfigurationFactory_h

#import <Foundation/Foundation.h>
@import KSCrashRecording;

NS_ASSUME_NONNULL_BEGIN

/**
 * Factory for creating KSCrashConfiguration objects with Sentry-specific
 * defaults pre-wired.
 *
 * The @c isWritingReportCallback property on @c KSCrashConfiguration is
 * @c NS_SWIFT_UNAVAILABLE and must be set from ObjC. This factory provides a
 * single place where that callback is assigned together with the other
 * installation parameters.
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

@end

NS_ASSUME_NONNULL_END

#endif /* SentryKSCrashConfigurationFactory_h */
