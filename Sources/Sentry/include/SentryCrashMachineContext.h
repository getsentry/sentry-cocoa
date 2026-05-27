// Compatibility shim — forwards to upstream KSCrash.
//
// All sentrycrashmc_* symbols are aliases for their ksmc_* counterparts.
// The SentryCrashMachineContext struct is now KSMachineContext.
// The SentryCrashMC_NEW_CONTEXT macro allocates a KSMachineContext on the stack.

#ifndef HDR_SentryCrashMachineContext_h
#define HDR_SentryCrashMachineContext_h

#include "KSMachineContext.h"
#include "SentryCrashThread.h"

#ifdef __cplusplus
extern "C" {
#endif

// SentryCrashMachineContext is now an alias for KSMachineContext.
// Define the struct alias so that `struct SentryCrashMachineContext *` is a valid type.
typedef struct KSMachineContext SentryCrashMachineContext;

// Allocate on the stack just like the original macro.
#define SentryCrashMC_NEW_CONTEXT(NAME)                                                            \
    char sentrycrashmc_##NAME##_storage[sizeof(KSMachineContext)];                                 \
    struct KSMachineContext *NAME = (struct KSMachineContext *)sentrycrashmc_##NAME##_storage

// Function aliases: sentrycrashmc_* → ksmc_*
#define sentrycrashmc_getContextForThread ksmc_getContextForThread
#define sentrycrashmc_getContextForSignal ksmc_getContextForSignal
#define sentrycrashmc_getThreadFromContext ksmc_getThreadFromContext
#define sentrycrashmc_getThreadCount ksmc_getThreadCount
#define sentrycrashmc_getThreadAtIndex ksmc_getThreadAtIndex
#define sentrycrashmc_indexOfThread ksmc_indexOfThread
#define sentrycrashmc_isCrashedContext ksmc_isCrashedContext
#define sentrycrashmc_canHaveCPUState ksmc_canHaveCPUState
#define sentrycrashmc_hasValidExceptionRegisters ksmc_hasValidExceptionRegisters
#define sentrycrashmc_suspendEnvironment ksmc_suspendEnvironment

// sentrycrashmc_resumeEnvironment(threads, numThreads) — old API passes values, not pointers.
// Provide an inline wrapper that adapts to ksmc_resumeEnvironment(*, *) taking pointers.
static inline void
sentrycrashmc_resumeEnvironment(thread_act_array_t threads, mach_msg_type_number_t numThreads)
{
    ksmc_resumeEnvironment(&threads, &numThreads);
}

// Sentry-specific: suspend only when thread count is within limit.
// KSCrash has no equivalent, so we implement it inline.
#include <mach/mach.h>
static inline void
sentrycrashmc_suspendEnvironment_upToMaxSupportedThreads(thread_act_array_t *suspendedThreads,
    mach_msg_type_number_t *numSuspendedThreads, mach_msg_type_number_t maxSupportedThreads)
{
    // Get the count first without suspending.
    mach_port_t task = mach_task_self();
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t count = 0;
    if (task_threads(task, &threads, &count) != KERN_SUCCESS) {
        *suspendedThreads = NULL;
        *numSuspendedThreads = 0;
        return;
    }
    // Deallocate the temporary list — we just needed the count.
    vm_deallocate(task, (vm_address_t)threads, count * sizeof(thread_t));

    if (count > maxSupportedThreads) {
        *suspendedThreads = NULL;
        *numSuspendedThreads = 0;
        return;
    }
    ksmc_suspendEnvironment(suspendedThreads, numSuspendedThreads);
}

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashMachineContext_h
