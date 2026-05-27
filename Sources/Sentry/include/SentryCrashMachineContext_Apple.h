// Compatibility shim — forwards to upstream KSCrash.
//
// The SentryCrashMachineContext type is now an alias for KSMachineContext.
// This header is kept so existing #include "SentryCrashMachineContext_Apple.h" continue to compile.

#ifndef HDR_SentryCrashMachineContext_Apple_h
#define HDR_SentryCrashMachineContext_Apple_h

#include "KSMachineContext_Apple.h"

// SentryCrashMachineContext is now a typedef alias for KSMachineContext;
// the typedef is defined in SentryCrashMachineContext.h.
#define SENTRY_CRASH_MAX_THREADS MAX_CAPTURED_THREADS

#endif // HDR_SentryCrashMachineContext_Apple_h
