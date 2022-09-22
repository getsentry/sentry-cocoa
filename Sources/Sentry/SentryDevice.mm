#import "SentryDevice.h"
#import "SentryLog.h"
#import <sys/sysctl.h>
#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

namespace {
/**
 * @brief Get an iOS hardware model name, or for mac devices, either the hardware model name or CPU architecture of the device, depending on the option provided.
 * @note For an iOS CPU architecture name, `getArchitectureName` must be used.
 * @discussion The values returned are different between iOS and macOS depending on which option is provided. Some examples of values
 * returned on different devices:
 * @code
 * | device                        | machine    | model          |
 * ---------------------------------------------------------------
 * | m1 mbp                        | arm64      | MacBookPro18,3 |
 * | iphone 13 mini                | iPhone14,4 | D16AP          |
 * | intel imac                    | x86_64     | iMac20,1       |
 * | iphone simulator on m1 mac    | arm64      | MacBookPro18,3 |
 * | iphone simulator on intel mac | x86_64     | iMac20,1       |
 * @endcode
 * @seealso See
 * https://www.cocoawithlove.com/blog/2016/03/08/swift-wrapper-for-sysctl.html#looking-for-the-source
 * for more info.
 * @return @c sysctl value for the combination of @c CTL_HW and the provided other flag in the
 * type parameter.
 */
NSString *
getHardwareDescription(int type)
{
    int mib[2];
    char name[128];
    size_t len;

    mib[0] = CTL_HW;
    mib[1] = type;
    len = sizeof(name);
    if (SENTRY_LOG_ERRNO(sysctl(mib, 2, &name, &len, NULL, 0)) != 0) {
        return @"";
    }
    return [NSString stringWithUTF8String:name];
}

NSString *getCPUType(NSNumber *_Nullable subtype) {
    cpu_type_t type;
    size_t typeSize = sizeof(type);
    if (SENTRY_LOG_ERRNO(sysctlbyname("hw.cputype", &type, &typeSize, NULL, 0)) != 0) {
        if (subtype != nil) {
            return [NSString stringWithFormat:@"no CPU type for unknown subtype %d", subtype.intValue];
        }
        return @"no CPU type or subtype";
    }
    switch (type) {
        default:
            if (subtype != nil) {
                return [NSMutableString stringWithFormat:@"unknown CPU type (%d) and subtype (%d)", type, subtype.intValue];
            }
            return [NSMutableString stringWithFormat:@"unknown CPU type (%d)", type];
        case CPU_TYPE_X86_64:
            // I haven't observed this branch being taken for 64-bit x86 architectures. Rather, the
            // x86 branch is taken, and then the subtype is reported as the 64-bit
            // subtype. Tested on a 2020 iMac. (armcknight 21 Sep 2022)
            return @"x86_64";
        case CPU_TYPE_X86:
            return @"x86";
        case CPU_TYPE_ARM:
            return @"arm";
        case CPU_TYPE_ARM64:
            return @"arm64";
        case CPU_TYPE_ARM64_32:
            return @"arm64_32";
    }
}
} // namespace

NSString *
getCPUArchitecture(void)
{
    cpu_subtype_t subtype;
    size_t subtypeSize = sizeof(subtype);
    if (SENTRY_LOG_ERRNO(sysctlbyname("hw.cpusubtype", &subtype, &subtypeSize, NULL, 0)) != 0) {
        return getCPUType(nil);
    }
    switch (subtype) {
        default:
            return getCPUType(@(subtype));
        case CPU_SUBTYPE_X86_64_H:
            return @"x86_64H";
        case CPU_SUBTYPE_X86_64_ALL:
            return @"x86_64";
        case CPU_SUBTYPE_ARM_V6:
            return @"armv6";
        case CPU_SUBTYPE_ARM_V7:
            return @"armv7";
        case CPU_SUBTYPE_ARM_V7S:
            return @"armv7s";
        case CPU_SUBTYPE_ARM_V7K:
            return @"armv7k";
        case CPU_SUBTYPE_ARM64_V8:
            // this also catches CPU_SUBTYPE_ARM64_32_V8 since they are both defined as
            // ((cpu_subtype_t) 1)
            return @"armv8";
        case CPU_SUBTYPE_ARM64E:
            return @"arm64e";
    }
}

NSString *
getOSName(void)
{
#if SENTRY_HAS_UIKIT
    return UIDevice.currentDevice.systemName;
#else
    return @"macOS";
#endif // SENTRY_HAS_UIKIT
}

NSString *
getOSVersion(void)
{
#if SENTRY_HAS_UIKIT
    return UIDevice.currentDevice.systemVersion;
#else
    // based off of
    // https://github.com/lmirosevic/GBDeviceInfo/blob/98dd3c75bb0e1f87f3e0fd909e52dcf0da4aa47d/GBDeviceInfo/GBDeviceInfo_OSX.m#L107-L133
    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)]) {
        const auto version = [[NSProcessInfo processInfo] operatingSystemVersion];
        return [NSString stringWithFormat:@"%ld.%ld.%ld", (long)version.majorVersion,
                         (long)version.minorVersion, (long)version.patchVersion];
    } else {
        SInt32 major, minor, patch;

#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
        Gestalt(gestaltSystemVersionMajor, &major);
        Gestalt(gestaltSystemVersionMinor, &minor);
        Gestalt(gestaltSystemVersionBugFix, &patch);
#    pragma clang diagnostic pop

        return [NSString stringWithFormat:@"%d.%d.%d", major, minor, patch];
    }
#endif // SENTRY_HAS_UIKIT
}

NSString *
getDeviceModel(void)
{
#if defined(HW_PRODUCT)
    if(@available(iOS 14, macOS 11, *)) {
        return getHardwareDescription(HW_PRODUCT);
    }
#endif // defined(HW_PRODUCT)

#if SENTRY_HAS_UIKIT
#    if TARGET_OS_SIMULATOR
        return getHardwareDescription(HW_MODEL);
#    else
        return getHardwareDescription(HW_MACHINE);
#    endif // TARGET_OS_SIMULATOR
#else
        return getHardwareDescription(HW_MODEL);
#endif // SENTRY_HAS_UIKIT
}

NSString *
getOSBuildNumber(void)
{
    char str[32];
    size_t size = sizeof(str);
    int cmd[2] = { CTL_KERN, KERN_OSVERSION };
    if (SENTRY_LOG_ERRNO(sysctl(cmd, sizeof(cmd) / sizeof(*cmd), str, &size, NULL, 0)) == 0) {
        return [NSString stringWithUTF8String:str];
    }
    return @"";
}

BOOL
isSimulatorBuild(void)
{
#if TARGET_OS_SIMULATOR
    return true;
#else
    return false;
#endif
}
