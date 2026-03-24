#ifndef HDR_SentryCrashMonitor_CPPException_ObjCHelper_h
#define HDR_SentryCrashMonitor_CPPException_ObjCHelper_h

#include "SentryCrashStackCursor.h"
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Extract NSException info from the current in-flight C++ exception.
 *
 * Must be called while an ObjC exception is active in the C++ terminate handler.
 *
 * @param outName On success, points to the UTF8 name. Valid until the exception is destroyed.
 * @param outReason On success, points to the UTF8 reason. Valid until the exception is destroyed.
 * @param outCursor On success, initialized with the exception's callStackReturnAddresses.
 * @return Allocated callstack array (caller must free), or NULL.
 */
uintptr_t *sentrycrashcm_extractCurrentObjCException(
    const char **outName, const char **outReason, SentryCrashStackCursor *outCursor);

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashMonitor_CPPException_ObjCHelper_h
