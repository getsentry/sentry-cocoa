// Compatibility shim — forwards to upstream KSCrash.
//
// sentrycrashsysctl_* → kssysctl_*
// sentrycrashsysctl_currentProcessStartTime() — Sentry-specific helper not in KSCrash;
// implemented inline here using kssysctl_getProcessInfo.

#ifndef HDR_SentryCrashSysCtl_h
#define HDR_SentryCrashSysCtl_h

#include "KSSysCtl.h"
#include <sys/sysctl.h>
#include <unistd.h>

#ifdef __cplusplus
extern "C" {
#endif

// Function aliases
#define sentrycrashsysctl_int32 kssysctl_int32
#define sentrycrashsysctl_int32ForName kssysctl_int32ForName
#define sentrycrashsysctl_uint32 kssysctl_uint32
#define sentrycrashsysctl_uint32ForName kssysctl_uint32ForName
#define sentrycrashsysctl_int64 kssysctl_int64
#define sentrycrashsysctl_int64ForName kssysctl_int64ForName
#define sentrycrashsysctl_uint64 kssysctl_uint64
#define sentrycrashsysctl_uint64ForName kssysctl_uint64ForName
#define sentrycrashsysctl_string kssysctl_string
#define sentrycrashsysctl_stringForName kssysctl_stringForName
#define sentrycrashsysctl_timeval kssysctl_timeval
#define sentrycrashsysctl_timevalForName kssysctl_timevalForName
#define sentrycrashsysctl_getProcessInfo kssysctl_getProcessInfo
#define sentrycrashsysctl_getMacAddress kssysctl_getMacAddress

// Sentry-specific helper: get the start time of the current process.
static inline struct timeval
sentrycrashsysctl_currentProcessStartTime(void)
{
    struct kinfo_proc procInfo;
    if (kssysctl_getProcessInfo(getpid(), &procInfo)) {
        return procInfo.kp_proc.p_starttime;
    }
    struct timeval zero = { 0, 0 };
    return zero;
}

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashSysCtl_h
