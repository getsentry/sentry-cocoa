// Compatibility shim — forwards to upstream KSCrash.

#ifndef HDR_SentryCrashFileUtils_h
#define HDR_SentryCrashFileUtils_h

#include "KSFileUtils.h"

#ifdef __cplusplus
extern "C" {
#endif

#define sentrycrashfu_writeBytesToFD ksfu_writeBytesToFD
#define sentrycrashfu_readBytesFromFD ksfu_readBytesFromFD
#define sentrycrashfu_lastPathEntry ksfu_lastPathEntry

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashFileUtils_h
