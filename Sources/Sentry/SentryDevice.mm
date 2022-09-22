#import "SentryDevice.h"
#import "SentryLog.h"
#import <sys/sysctl.h>
#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

namespace {
/**
 * @brief Get the hardware description of the device.
 * @discussion The values returned are different between iOS and macOS. Some examples of values
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

#if SENTRY_HAS_UIKIT && !TARGET_OS_SIMULATOR
NSString *
getArchitectureName_sysctlbyname()
{
    size_t size;
    cpu_type_t type;
    cpu_subtype_t subtype;
    size = sizeof(type);
    NSMutableString *nameStr;
    if (SENTRY_LOG_ERRNO(sysctlbyname("hw.cputype", &type, &size, NULL, 0)) == 0) {
        switch (type) {
        case CPU_TYPE_X86_64:
            // I haven't observed this branch being taken for 64-bit x86 architectures. Rather, the
            // x86 branch below is taken, and then the subtype retrieved below reports the 64-bit
            // subtype. Tested on a 2020 iMac. (armcknight 21 Sep 2022)
        case CPU_TYPE_X86:
            nameStr = [NSMutableString stringWithString:@"x86"];
            break;
        case CPU_TYPE_ARM:
            nameStr = [NSMutableString stringWithString:@"arm"];
            break;
        case CPU_TYPE_ARM64:
            nameStr = [NSMutableString stringWithString:@"arm64"];
            break;
        case CPU_TYPE_ARM64_32:
            nameStr = [NSMutableString stringWithString:@"arm64_32"];
            break;
        default:
            return [NSMutableString stringWithFormat:@"unknown CPU type (%d)", type];
        }
    }

    size = sizeof(subtype);
    if (SENTRY_LOG_ERRNO(sysctlbyname("hw.cpusubtype", &subtype, &size, NULL, 0)) == 0) {
        switch (subtype) {
        default:
            break;
        case CPU_SUBTYPE_X86_64_H:
            [nameStr appendString:@"_64H"];
            break;
        case CPU_SUBTYPE_X86_64_ALL:
            [nameStr appendString:@"_64"];
            break;
        case CPU_SUBTYPE_ARM_V6:
            [nameStr appendString:@"v6"];
            break;
        case CPU_SUBTYPE_ARM_V7:
            [nameStr appendString:@"v7"];
            break;
        case CPU_SUBTYPE_ARM_V7S:
            [nameStr appendString:@"v7s"];
            break;
        case CPU_SUBTYPE_ARM_V7K:
            [nameStr appendString:@"v7k"];
            break;
        case CPU_SUBTYPE_ARM64_V8:
            // this also catches CPU_SUBTYPE_ARM64_32_V8 since they are both defined as
            // ((cpu_subtype_t) 1)
            [nameStr appendString:@"v8"];
            break;
        case CPU_SUBTYPE_ARM64E:
            [nameStr appendString:@"e"];
            break;
        }
    }

    return nameStr;
}
#endif // SENTRY_HAS_UIKIT && !TARGET_OS_SIMULATOR
} // namespace

NSString *
getCPUArchitecture(void)
{
#if SENTRY_HAS_UIKIT
#    if TARGET_OS_SIMULATOR
    return getHardwareDescription(HW_MACHINE);
#    else
    return getArchitectureName_sysctlbyname();
#    endif // TARGET_OS_SIMULATOR
#else
    return getHardwareDescription(HW_MACHINE);
#endif // SENTRY_HAS_UIKIT
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
