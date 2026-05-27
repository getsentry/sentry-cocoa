// Compatibility shim — forwards to upstream KSCrash.

#ifndef HDR_SentryCrashMemory_h
#define HDR_SentryCrashMemory_h

#include "KSMemory.h"

#ifdef __cplusplus
extern "C" {
#endif

#define sentrycrashmem_isMemoryReadable ksmem_isMemoryReadable
#define sentrycrashmem_maxReadableBytes ksmem_maxReadableBytes
#define sentrycrashmem_copySafely ksmem_copySafely
#define sentrycrashmem_copyMaxPossible ksmem_copyMaxPossible

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashMemory_h
