// Compatibility shim — forwards to upstream KSCrash.
//
// SentryCrashThread is now an alias for KSThread.
// All sentrycrashthread_* functions map to ksthread_* equivalents.

#ifndef HDR_SentryCrashThread_h
#define HDR_SentryCrashThread_h

#include "KSThread.h"

#ifdef __cplusplus
extern "C" {
#endif

// Type alias — typedef (not #define) so Swift can see SentryCrashThread.
typedef KSThread SentryCrashThread;

// Function aliases — static inline so Swift can call them (macros are invisible to Swift).
static inline SentryCrashThread
sentrycrashthread_self(void)
{
    return ksthread_self();
}
#define sentrycrashthread_getThreadName ksthread_getThreadName
#define sentrycrashthread_getQueueName ksthread_getQueueName

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashThread_h
