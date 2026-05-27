// Compatibility shim — forwards to upstream KSCrash.

#ifndef SentryCrashStackCursor_MachineContext_h
#define SentryCrashStackCursor_MachineContext_h

#include "KSStackCursor_MachineContext.h"
#include "SentryCrashStackCursor.h"

#define sentrycrashsc_initWithMachineContext kssc_initWithMachineContext

// The original SentryCrash value was 100; keep the same limit for compatibility.
#define MAX_STACKTRACE_LENGTH 100

#endif // SentryCrashStackCursor_MachineContext_h
