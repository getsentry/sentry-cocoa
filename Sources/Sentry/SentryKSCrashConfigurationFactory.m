#import "SentryKSCrashConfigurationFactory.h"
#import "SentryKSCrashReportCallback.h"

@implementation SentryKSCrashConfigurationFactory

+ (KSCrashConfiguration *)configurationWithInstallPath:(NSString *)installPath
                                              monitors:(KSCrashMonitorType)monitors
                               enableSigTermMonitoring:(BOOL)sigterm
                                    enableSwapCxaThrow:(BOOL)cxxSwap
{
    return [self configurationWithInstallPath:installPath
                                     monitors:monitors
                      enableSigTermMonitoring:sigterm
                           enableSwapCxaThrow:cxxSwap
                         persistTracesOnCrash:NO];
}

+ (KSCrashConfiguration *)configurationWithInstallPath:(NSString *)installPath
                                              monitors:(KSCrashMonitorType)monitors
                               enableSigTermMonitoring:(BOOL)sigterm
                                    enableSwapCxaThrow:(BOOL)cxxSwap
                                  persistTracesOnCrash:(BOOL)persistTracesOnCrash
{
    KSCrashConfiguration *config = [[KSCrashConfiguration alloc] init];
    config.installPath = installPath;
    config.monitors = monitors;
    config.enableSigTermMonitoring = sigterm;
    config.enableSwapCxaThrow = cxxSwap;
    config.isWritingReportCallback = sentry_kscrash_isWritingReportCallback;
    if (persistTracesOnCrash) {
        config.willWriteReportCallback = sentry_kscrash_willWriteReportCallback;
    }
    return config;
}

@end
