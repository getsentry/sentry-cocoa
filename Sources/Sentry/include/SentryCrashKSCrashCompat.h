// SentryCrashKSCrashCompat.h
//
// Compatibility shim that maps SentryCrash utility symbols to their KSCrash equivalents
// when ENABLE_KSCRASH is defined. Only the three subsystems with direct counterparts are
// bridged here: JSON codec, file utils, and sysctl.
//
// Stack-cursor, binary-image, dynamic-linker, and async-stitching symbols still come from
// the SentryCrash tools layer, which stays compiled in both modes.

#pragma once

#ifdef ENABLE_KSCRASH

// --- JSON Codec ---
#    include <KSJSONCodec.h>
typedef KSJSONEncodeContext SentryCrashJSONEncodeContext;
typedef KSJSONAddDataFunc SentryCrashJSONAddDataFunc;
#    define SentryCrashJSON_OK KSJSON_OK
#    define SentryCrashJSON_SIZE_AUTOMATIC KSJSON_SIZE_AUTOMATIC
#    define SentryCrashJSON_ERROR_CANNOT_ADD_DATA KSJSON_ERROR_CANNOT_ADD_DATA
#    define sentrycrashjson_beginEncode ksjson_beginEncode
#    define sentrycrashjson_endEncode ksjson_endEncode
#    define sentrycrashjson_addBooleanElement ksjson_addBooleanElement
#    define sentrycrashjson_addIntegerElement ksjson_addIntegerElement
#    define sentrycrashjson_addUIntegerElement ksjson_addUIntegerElement
#    define sentrycrashjson_addFloatingPointElement ksjson_addFloatingPointElement
#    define sentrycrashjson_addNullElement ksjson_addNullElement
#    define sentrycrashjson_addStringElement ksjson_addStringElement
#    define sentrycrashjson_beginStringElement ksjson_beginStringElement
#    define sentrycrashjson_appendStringElement ksjson_appendStringElement
#    define sentrycrashjson_endStringElement ksjson_endStringElement
#    define sentrycrashjson_addDataElement ksjson_addDataElement
#    define sentrycrashjson_beginObject ksjson_beginObject
#    define sentrycrashjson_beginArray ksjson_beginArray
#    define sentrycrashjson_endContainer ksjson_endContainer
#    define sentrycrashjson_stringForError ksjson_stringForError

// --- File Utils ---
#    include <KSFileUtils.h>
#    define sentrycrashfu_writeBytesToFD ksfu_writeBytesToFD
#    define sentrycrashfu_readBytesFromFD ksfu_readBytesFromFD

// --- SysCtl ---
#    include <KSSysCtl.h>
#    define sentrycrashsysctl_timeval kssysctl_timeval

// sentrycrashsysctl_currentProcessStartTime() has no direct KSCrash equivalent;
// implement as an inline wrapper using kssysctl_getProcessInfo().
#    include <sys/sysctl.h>
static inline struct timeval
sentrycrashsysctl_currentProcessStartTime(void)
{
    struct kinfo_proc info;
    if (kssysctl_getProcessInfo(getpid(), &info)) {
        return info.kp_proc.p_starttime;
    }
    struct timeval zero = { 0, 0 };
    return zero;
}

#else // !ENABLE_KSCRASH — include originals so this header is the single include point

#    import "SentryCrashFileUtils.h"
#    import "SentryCrashJSONCodec.h"
#    import "SentryCrashSysCtl.h"

#endif // ENABLE_KSCRASH
