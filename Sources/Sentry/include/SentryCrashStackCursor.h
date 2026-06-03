// Compatibility shim — forwards to upstream KSCrash.
//
// SentryCrashStackCursor is now an alias for KSStackCursor.
// SentryCrashStackEntry is aliased to the stackEntry inner struct of KSStackCursor.
// sentrycrashsc_* functions map to kssc_* equivalents.
//
// Sentry-specific additions kept here:
//   SentryCrashSC_ASYNC_MARKER — special frame marker for async stack stitching.

#ifndef SentryCrashStackCursor_h
#define SentryCrashStackCursor_h

#include "KSStackCursor.h"

#ifdef __cplusplus
extern "C" {
#endif

// Type alias — typedef (not #define) so Swift can see SentryCrashStackCursor as a type.
typedef KSStackCursor SentryCrashStackCursor;
#define SentryCrashSC_CONTEXT_SIZE KSSC_CONTEXT_SIZE
#define SentryCrashSC_STACK_OVERFLOW_THRESHOLD KSSC_STACK_OVERFLOW_THRESHOLD

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
#define SentryCrashSC_ASYNC_MARKER (UINTPTR_MAX - 1234)

#ifdef __cplusplus
}
#endif

#endif // SentryCrashStackCursor_h
