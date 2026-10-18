#if SDK_V10
#    include "SentryThreadSnapshot.h"
#    include <KSBacktrace.h>
#    include <KSLogger.h>
#    include <KSMachineContext.h>
#    include <KSStackCursor.h>
#    include <KSThread.h>
#    include <TargetConditionals.h>
#    include <mach/mach.h>
#    include <stdatomic.h>
#    include <stdlib.h>
#    include <string.h>

_Static_assert(SENTRY_THREAD_SNAPSHOT_MAX_FRAMES == KSSC_MAX_STACK_DEPTH,
    "Snapshot storage must follow KSCrash's remote-stack bound");
_Static_assert(
    SENTRY_THREAD_SNAPSHOT_NAME_LENGTH == sizeof(((thread_extended_info_data_t *)0)->pth_name),
    "Snapshot storage must follow Darwin's thread-name field size");

typedef enum {
    SentryCrashHandlerNotInstalled,
    SentryCrashHandlerInstalling,
    SentryCrashHandlerInstalled,
} SentryCrashHandlerInstallationState;

_Static_assert(ATOMIC_INT_LOCK_FREE == 2, "Installation readiness must be lock-free");
static atomic_int g_crashHandlerInstallation = SentryCrashHandlerNotInstalled;

void
sentryThreadInspectionWillInstallCrashHandler(void)
{
    int expected = SentryCrashHandlerNotInstalled;
    atomic_compare_exchange_strong_explicit(&g_crashHandlerInstallation, &expected,
        SentryCrashHandlerInstalling, memory_order_release, memory_order_relaxed);
}

void
sentryThreadInspectionDidInstallCrashHandler(bool succeeded)
{
    if (succeeded) {
        atomic_store_explicit(
            &g_crashHandlerInstallation, SentryCrashHandlerInstalled, memory_order_release);
    } else {
        int expected = SentryCrashHandlerInstalling;
        atomic_compare_exchange_strong_explicit(&g_crashHandlerInstallation, &expected,
            SentryCrashHandlerNotInstalled, memory_order_release, memory_order_relaxed);
    }
}

bool
sentryThreadInspectionCanCaptureRemote(bool requiresCrashHandler)
{
    int state = atomic_load_explicit(&g_crashHandlerInstallation, memory_order_acquire);
    return state == SentryCrashHandlerInstalled
        || (state == SentryCrashHandlerNotInstalled && !requiresCrashHandler);
}

static bool
enumerate(void *context, void **list, size_t *count)
{
    (void)context;
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t threadCount = 0;
    if (task_threads(mach_task_self(), &threads, &threadCount) != KERN_SUCCESS) {
        return false;
    }
    *list = threads;
    *count = threadCount;
    return true;
}

static void
releaseList(void *context, void *list, size_t count)
{
    (void)context;
    thread_act_array_t threads = list;
    for (size_t i = 0; i < count; i++) {
        mach_port_deallocate(mach_task_self(), threads[i]);
    }
    if (threads != NULL) {
        vm_deallocate(mach_task_self(), (vm_address_t)threads, count * sizeof(thread_t));
    }
}

static uintptr_t
threadAt(void *context, void *list, size_t index)
{
    (void)context;
    return ((thread_act_array_t)list)[index];
}

uintptr_t
sentryThreadInspectionCurrentThread(void)
{
    return ksthread_self();
}

static uintptr_t
currentThread(void *context)
{
    (void)context;
    return sentryThreadInspectionCurrentThread();
}

static uintptr_t
mainThread(void *context)
{
    (void)context;
    return ksthread_main();
}

static bool
isReserved(void *context, uintptr_t thread)
{
    (void)context;
    return ksmc_isReservedThread(thread);
}

static bool
suspendThread(void *context, uintptr_t thread)
{
    (void)context;
#    if TARGET_OS_WATCH
    (void)thread;
    return false;
#    else
    kern_return_t result = thread_suspend((thread_t)thread);
    if (result != KERN_SUCCESS) {
        KSLOG_ERROR("thread_suspend (0x%x) failed: %d", (thread_t)thread, result);
        return false;
    }
    return true;
#    endif
}

static size_t
captureSuspended(
    void *context, uintptr_t thread, uintptr_t *addresses, size_t capacity, bool *isTruncated)
{
    (void)context;
    // The driver guarantees that this target is suspended and keeps every other successfully
    // suspended target stopped throughout all unwinds. This KSCrash operation uses stack-local and
    // preallocated state plus a nonblocking atomic capture guard; it does not change suspension
    // counts. The driver/caller must have checked installation safety for its enumerated list.
    return (size_t)ksbt_captureBacktraceFromSuspendedMachThread(
        (thread_t)thread, addresses, (int)capacity, isTruncated);
}

static void
resumeThread(void *context, uintptr_t thread)
{
    (void)context;
#    if TARGET_OS_WATCH
    (void)thread;
#    else
    // Frames are already complete, and there is no safe corrective action for this diagnostic if
    // resume fails. Keep attempting the remaining resumes after recording the failure.
    kern_return_t result = thread_resume((thread_t)thread);
    if (result != KERN_SUCCESS) {
        KSLOG_ERROR("thread_resume (0x%x) failed: %d", (thread_t)thread, result);
    }
#    endif
}

bool
sentryThreadSnapshotCopyName(uintptr_t thread, char *buffer, size_t capacity)
{
    if (buffer == NULL || capacity == 0) {
        return false;
    }
    buffer[0] = '\0';
    // A retained Mach right does not keep pthread storage alive. Query the kernel instead of
    // converting to a potentially disappearing pthread_t after a target exits.
    thread_extended_info_data_t info = { 0 };
    mach_msg_type_number_t count = THREAD_EXTENDED_INFO_COUNT;
    if (thread_info((thread_t)thread, THREAD_EXTENDED_INFO, (thread_info_t)&info, &count)
        != KERN_SUCCESS) {
        return false;
    }
    info.pth_name[sizeof(info.pth_name) - 1] = '\0';
    strlcpy(buffer, info.pth_name, capacity);
    return true;
}

static bool
name(void *context, uintptr_t thread, char *buffer, size_t capacity)
{
    (void)context;
    return sentryThreadSnapshotCopyName(thread, buffer, capacity);
}

static void *
allocate(void *context, size_t count, size_t size)
{
    (void)context;
    return calloc(count, size);
}

static void
deallocate(void *context, void *allocation)
{
    (void)context;
    free(allocation);
}

SentryThreadSnapshotBackend
sentryThreadSnapshotKSCrashBackend(void)
{
    return (SentryThreadSnapshotBackend) {
        .enumerate = enumerate,
        .releaseList = releaseList,
        .threadAt = threadAt,
        .currentThread = currentThread,
        .mainThread = mainThread,
        .isReserved = isReserved,
        .suspend = suspendThread,
        .captureSuspended = captureSuspended,
        .resume = resumeThread,
        .name = name,
        .allocate = allocate,
        .deallocate = deallocate,
    };
}

static bool
canCapture(void *context)
{
    return sentryThreadInspectionCanCaptureRemote(*(bool *)context);
}

bool
sentryThreadSnapshotSystemCapture(
    bool captureStacks, bool requiresCrashHandler, SentryThreadSnapshotBuffer *output)
{
    SentryThreadSnapshotBackend backend = sentryThreadSnapshotKSCrashBackend();
    backend.context = &requiresCrashHandler;
    backend.canCapture = canCapture;
    return sentryThreadSnapshotCapture(&backend, captureStacks, output);
}

void
sentryThreadSnapshotSystemDestroy(SentryThreadSnapshotBuffer *output)
{
    SentryThreadSnapshotBackend backend = sentryThreadSnapshotKSCrashBackend();
    sentryThreadSnapshotDestroy(&backend, output);
}

#endif
