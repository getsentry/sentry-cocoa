#import "SentryKSCrashConfigurationFactory.h"
#import "SentryKSCrashReportCallback.h"

@implementation SentryKSCrashConfigurationFactory

+ (KSCrashConfiguration *)configurationWithInstallPath:(NSString *)installPath
                                              monitors:(KSCrashMonitorType)monitors
                               enableSigTermMonitoring:(BOOL)sigterm
                                    enableSwapCxaThrow:(BOOL)cxxSwap
{
    KSCrashConfiguration *config = [[KSCrashConfiguration alloc] init];
    config.installPath = installPath;
    config.monitors = monitors;
    config.enableSigTermMonitoring = sigterm;
    config.enableSwapCxaThrow = cxxSwap;
    config.isWritingReportCallback = sentry_kscrash_isWritingReportCallback;
    return config;
}

@end
