#import "SentryProcessInfo.h"
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import <unistd.h>

BOOL
isDebugging(void)
{
    struct kinfo_proc info;

    // Initialize the flags so that, if sysctl fails for some bizarre
    // reason, we get a predictable result.
    info.kp_proc.p_flag = 0;

    // Initialize mib, which tells sysctl the info we want, in this case
    // we're looking for information about a specific process ID.
    int mib[] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };

    // Call sysctl.
    size_t size = sizeof(info);
    int junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
    if (junk != 0) {
        printf("sysctl failed while trying to get kinfo_proc\n");
        return false;
    }

    // We're being debugged if the P_TRACED flag is set.
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

BOOL
isSimulator(void)
{
    NSOperatingSystemVersion ios9 = { 9, 0, 0 };
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    if ([processInfo isOperatingSystemAtLeastVersion:ios9]) {
        NSDictionary<NSString *, NSString *> *environment = [processInfo environment];
        NSString *simulator = [environment objectForKey:@"SIMULATOR_DEVICE_NAME"];
        return simulator != nil;
    } else {
        UIDevice *currentDevice = [UIDevice currentDevice];
        return ([currentDevice.model rangeOfString:@"Simulator"].location != NSNotFound);
    }
}
