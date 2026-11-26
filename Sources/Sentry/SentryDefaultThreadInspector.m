#import "SentryDefaultThreadInspector.h"
#if !SDK_V10
#    import "SentryCrashMachineContext.h"
#    include "SentryCrashStackCursor_MachineContext.h"
#endif
#import "SentryCrashStackEntryMapper.h"
#import "SentryStacktraceBuilder.h"
#import "SentrySwift.h"
#include <stdlib.h>

#if !SDK_V10
// V9-only compatibility limits. Remove this helper when V9 is retired.
static const unsigned int maxSupportedThreads = 70;

typedef struct {
    SentryCrashThread thread;
    SentryCrashStackEntry stackEntries[MAX_STACKTRACE_LENGTH];
    unsigned int stackLength;
} SentryDefaultThreadInspectorThreadInfo;

struct SentryDefaultThreadInspectorThreadInfoBuffer {
    SentryCrashThread currentThread;
    unsigned int threadCount;
    SentryDefaultThreadInspectorThreadInfo threadInfos[70];
};

#endif

// Model construction is always outside the C capture suspension window.
SentryStacktraceBuilder *_Nonnull sentryDefaultThreadInspectorCreateStacktraceBuilder(
    NSArray<NSString *> *_Nonnull inAppIncludes)
{
    SentryInAppLogic *inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:inAppIncludes];
    SentryCrashStackEntryMapper *crashStackEntryMapper =
        [[SentryCrashStackEntryMapper alloc] initWithInAppLogic:inAppLogic];
    return [[SentryStacktraceBuilder alloc] initWithCrashStackEntryMapper:crashStackEntryMapper];
}

#if !SDK_V10
static unsigned int
getStackEntriesFromThread(SentryCrashThread thread, struct SentryCrashMachineContext *context,
    SentryCrashStackEntry *buffer, unsigned int maxEntries)
{
    sentrycrashmc_getContextForThread(thread, context, false);
    SentryCrashStackCursor stackCursor;

    sentrycrashsc_initWithMachineContext(&stackCursor, MAX_STACKTRACE_LENGTH, context);

    unsigned int entries = 0;
    while (stackCursor.advanceCursor(&stackCursor)) {
        if (entries == maxEntries) {
            break;
        }
        buffer[entries] = stackCursor.stackEntry;
        entries++;
    }

    return entries;
}

SentryDefaultThreadInspectorThreadInfoBuffer *_Nullable sentryDefaultThreadInspectorCaptureThreads(
    void)
{
    SentryDefaultThreadInspectorThreadInfoBuffer *buffer
        = calloc(1, sizeof(SentryDefaultThreadInspectorThreadInfoBuffer));
    if (buffer == NULL) {
        return NULL;
    }

    SentryCrashMC_NEW_CONTEXT(context);
    buffer->currentThread = sentrycrashthread_self();

    thread_act_array_t suspendedThreads = NULL;
    mach_msg_type_number_t numSuspendedThreads = 0;

    sentrycrashmc_suspendEnvironment_upToMaxSupportedThreads(
        &suspendedThreads, &numSuspendedThreads, maxSupportedThreads);
    // DANGER: Do not try to allocate memory in the heap or call Objective-C code in this section.
    // Doing so when the threads are suspended may lead to deadlocks or crashes.

    for (unsigned int i = 0; i < numSuspendedThreads; i++) {
        SentryDefaultThreadInspectorThreadInfo *threadInfo = &buffer->threadInfos[i];
        threadInfo->thread = suspendedThreads[i];

        if (suspendedThreads[i] != buffer->currentThread) {
            threadInfo->stackLength = getStackEntriesFromThread(
                suspendedThreads[i], context, threadInfo->stackEntries, MAX_STACKTRACE_LENGTH);
        }
    }

    if (numSuspendedThreads > 0) {
        sentrycrashmc_resumeEnvironment(suspendedThreads, numSuspendedThreads);
    }
    // DANGER END: You may call Objective-C code again or allocate memory.

    buffer->threadCount = numSuspendedThreads;
    return buffer;
}

void
sentryDefaultThreadInspectorFreeThreadInfoBuffer(
    SentryDefaultThreadInspectorThreadInfoBuffer *_Nullable buffer)
{
    free(buffer);
}

unsigned int
sentryDefaultThreadInspectorGetThreadCount(
    const SentryDefaultThreadInspectorThreadInfoBuffer *_Nonnull buffer)
{
    return buffer->threadCount;
}

SentryCrashThread
sentryDefaultThreadInspectorGetCurrentThread(
    const SentryDefaultThreadInspectorThreadInfoBuffer *_Nonnull buffer)
{
    return buffer->currentThread;
}

SentryCrashThread
sentryDefaultThreadInspectorGetThread(
    const SentryDefaultThreadInspectorThreadInfoBuffer *_Nonnull buffer, unsigned int index)
{
    return buffer->threadInfos[index].thread;
}

SentryCrashStackEntry *_Nonnull sentryDefaultThreadInspectorGetStackEntries(
    SentryDefaultThreadInspectorThreadInfoBuffer *_Nonnull buffer, unsigned int index)
{
    return buffer->threadInfos[index].stackEntries;
}

unsigned int
sentryDefaultThreadInspectorGetStackLength(
    const SentryDefaultThreadInspectorThreadInfoBuffer *_Nonnull buffer, unsigned int index)
{
    return buffer->threadInfos[index].stackLength;
}
#endif
