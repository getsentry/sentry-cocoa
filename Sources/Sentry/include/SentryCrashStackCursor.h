// Compatibility shim — forwards to upstream KSCrash.
//
// SentryCrashStackEntry is aliased to the stackEntry inner struct of KSStackCursor.
//
// Sentry-specific additions kept here:
//   SentryCrashSC_ASYNC_MARKER — special frame marker for async stack stitching.

#ifndef SentryCrashStackCursor_h
#define SentryCrashStackCursor_h

#include "KSStackCursor.h"

#ifdef __cplusplus
extern "C" {
#endif

// SentryCrashStackEntry is the anonymous struct type of KSStackCursor.stackEntry.
// We can't typedef it directly, so we replicate the fields as a named type.
// Code that accesses cursor.stackEntry.* works directly via KSStackCursor.
// Code that takes SentryCrashStackEntry as a value type needs this typedef.
typedef struct {
    uintptr_t address;
    const char *imageName;
    uintptr_t imageAddress;
    const char *symbolName;
    uintptr_t symbolAddress;
} SentryCrashStackEntry;

/** A special marker frame to denote a chained async stacktrace (Sentry-specific). */
static uint64_t SentryCrashSC_ASYNC_MARKER = UINTPTR_MAX - 1234;

#ifdef __cplusplus
}
#endif

#endif // SentryCrashStackCursor_h
