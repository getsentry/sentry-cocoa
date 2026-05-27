// Compatibility shim — forwards to upstream KSCrash.

#ifndef HDR_SentryCrashDebug_h
#define HDR_SentryCrashDebug_h

#include "KSDebug.h"

#ifdef __cplusplus
extern "C" {
#endif

#define sentrycrashdebug_isBeingTraced ksdebug_isBeingTraced

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashDebug_h
