#include "MachCaptureObserver.h"
#include <KSMachineContext.h>
#include <KSThread.h>
#include <dlfcn.h>
#include <stdlib.h>

static _Thread_local bool observing;
static _Thread_local MachCaptureObservation observation;
static _Thread_local thread_t failSuspendTarget;
static _Thread_local thread_t failStateTarget;
static _Thread_local thread_t current;
static _Thread_local kern_return_t (*realSuspend)(thread_act_t);
static _Thread_local kern_return_t (*realResume)(thread_act_t);
static _Thread_local kern_return_t (*realGetState)(
    thread_act_t, thread_state_flavor_t, thread_state_t, mach_msg_type_number_t *);

static void
resolveSymbols(void)
{
    if (realSuspend == NULL) {
        realSuspend = dlsym(RTLD_NEXT, "thread_suspend");
        realResume = dlsym(RTLD_NEXT, "thread_resume");
        realGetState = dlsym(RTLD_NEXT, "thread_get_state");
        if (realSuspend == NULL || realResume == NULL || realGetState == NULL) {
            abort();
        }
    }
}

void
beginMachCaptureObservation(thread_t failSuspend, thread_t failState)
{
    resolveSymbols();
    observation = (MachCaptureObservation) { 0 };
    failSuspendTarget = failSuspend;
    failStateTarget = failState;
    current = (thread_t)ksthread_self();
    observing = true;
}

MachCaptureObservation
endMachCaptureObservation(void)
{
    observing = false;
    return observation;
}

kern_return_t
thread_suspend(thread_act_t target)
{
    resolveSymbols();
    if (observing) {
        observation.suspendAttempts++;
        observation.touchedReserved |= ksmc_isReservedThread(target);
        observation.touchedCurrent |= target == current;
        if (target == failSuspendTarget) {
            return KERN_FAILURE;
        }
    }
    kern_return_t result = realSuspend(target);
    if (observing && result == KERN_SUCCESS) {
        observation.suspensions++;
        observation.active++;
        if (observation.active > observation.maxActive) {
            observation.maxActive = observation.active;
        }
    }
    return result;
}

kern_return_t
thread_resume(thread_act_t target)
{
    // Every intercepted resume in these tests follows a suspend, which resolves all symbols.
    kern_return_t result = realResume(target);
    if (observing) {
        observation.resumptions++;
        if (result == KERN_SUCCESS && observation.active > 0) {
            observation.active--;
        }
    }
    return result;
}

kern_return_t
thread_get_state(thread_act_t target, thread_state_flavor_t flavor, thread_state_t state,
    mach_msg_type_number_t *count)
{
    if (observing && target == failStateTarget) {
        return KERN_FAILURE;
    }
    // The first get-state outside capture has no active suspension.
    if (realGetState == NULL) {
        resolveSymbols();
    }
    return realGetState(target, flavor, state, count);
}
