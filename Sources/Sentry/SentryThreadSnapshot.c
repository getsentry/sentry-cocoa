#include "SentryThreadSnapshot.h"
#include <stdatomic.h>

// Coordinates the SDK's nonfatal bulk-inspection and profiler suspension paths. atomic_flag is
// guaranteed lock-free, so a contender can yield without waiting on an owner that may have
// suspended its thread.
static atomic_flag g_threadSuspensionAdmission = ATOMIC_FLAG_INIT;

bool
sentryThreadSuspensionTryAcquire(void)
{
    return !atomic_flag_test_and_set_explicit(&g_threadSuspensionAdmission, memory_order_acquire);
}

void
sentryThreadSuspensionRelease(void)
{
    atomic_flag_clear_explicit(&g_threadSuspensionAdmission, memory_order_release);
}

#if SDK_V10
#    include <string.h>

bool
sentryThreadSnapshotCapture(const SentryThreadSnapshotBackend *backend, bool captureStacks,
    SentryThreadSnapshotBuffer *output)
{
    *output = (SentryThreadSnapshotBuffer) { 0 };
    void *list = NULL;
    size_t count = 0;
    if (!backend->enumerate(backend->context, &list, &count)) {
        return false;
    }

    // Validate the result-buffer byte size before allocation, initialization, or reading the list.
    if (count > SIZE_MAX / sizeof(SentryThreadSnapshot)) {
        backend->releaseList(backend->context, list, count);
        return false;
    }
    const size_t resultSize = count * sizeof(SentryThreadSnapshot);
    SentryThreadSnapshot *threads = NULL;
    if (count > 0) {
        threads = backend->allocate(backend->context, count, sizeof(*threads));
        if (threads == NULL) {
            backend->releaseList(backend->context, list, count);
            return false;
        }
        memset(threads, 0, resultSize);
    }

    // An installation starting after enumeration can only introduce new infrastructure threads,
    // which are not in this list. Checking the policy before enumeration would leave a race.
    captureStacks
        = captureStacks && (backend->canCapture == NULL || backend->canCapture(backend->context));
    uintptr_t currentThread = backend->currentThread(backend->context);
    uintptr_t mainThread = backend->mainThread(backend->context);

    // Resolve everything that can invoke arbitrary code before stopping any target. In particular,
    // reserved membership cannot be queried after the first suspension has succeeded.
    bool hasEligibleThread = false;
    for (size_t i = 0; i < count; i++) {
        SentryThreadSnapshot *snapshot = &threads[i];
        snapshot->thread = backend->threadAt(backend->context, list, i);
        snapshot->index = i;
        snapshot->isCurrent = snapshot->thread == currentThread;
        snapshot->isMain = snapshot->thread == mainThread;
        snapshot->status = SentryThreadCaptureNotRequested;
        if (captureStacks) {
            if (snapshot->isCurrent) {
                // The SDK's current-thread stack provider remains responsible for this stack.
                snapshot->status = SentryThreadCaptureCurrent;
            } else if (backend->isReserved(backend->context, snapshot->thread)) {
                snapshot->status = SentryThreadCaptureReserved;
            } else {
                snapshot->status = SentryThreadCaptureUnavailable;
                hasEligibleThread = true;
            }
        }
    }

    // Admission is process-wide because every task thread can include another capture coordinator.
    // Never wait here: the current owner may already have suspended this caller.
    bool ownsSuspensionAdmission
        = captureStacks && hasEligibleThread && sentryThreadSuspensionTryAcquire();
    if (ownsSuspensionAdmission) {
        // No allocation, names, model construction, or other extensible callbacks are allowed from
        // the first successful suspension through the final balancing resume attempt.
        for (size_t i = 0; i < count; i++) {
            SentryThreadSnapshot *snapshot = &threads[i];
            if (snapshot->status == SentryThreadCaptureUnavailable) {
                snapshot->wasSuspended = backend->suspend(backend->context, snapshot->thread);
            }
        }
        for (size_t i = 0; i < count; i++) {
            SentryThreadSnapshot *snapshot = &threads[i];
            if (!snapshot->wasSuspended) {
                continue;
            }
            snapshot->frameCount = backend->captureSuspended(backend->context, snapshot->thread,
                snapshot->addresses, SENTRY_THREAD_SNAPSHOT_MAX_FRAMES, &snapshot->isTruncated);
            if (snapshot->frameCount > SENTRY_THREAD_SNAPSHOT_MAX_FRAMES) {
                // A bad count must not propagate into model conversion.
                snapshot->frameCount = 0;
                snapshot->isTruncated = false;
            }
            snapshot->status = snapshot->frameCount == 0 ? SentryThreadCaptureUnavailable
                                                         : SentryThreadCaptureSucceeded;
        }
        for (size_t i = 0; i < count; i++) {
            SentryThreadSnapshot *snapshot = &threads[i];
            if (snapshot->wasSuspended) {
                // Resume failure cannot invalidate frames already captured. The backend logs where
                // appropriate; this path still attempts every remaining balancing resume.
                backend->resume(backend->context, snapshot->thread);
            }
        }
        sentryThreadSuspensionRelease();
    }

    for (size_t i = 0; i < count; i++) {
        SentryThreadSnapshot *snapshot = &threads[i];
        // Keep the enumeration rights until names have been copied, not just until resumption.
        if (!backend->name(backend->context, snapshot->thread, snapshot->name,
                SENTRY_THREAD_SNAPSHOT_NAME_LENGTH)) {
            snapshot->name[0] = '\0';
        }
        snapshot->name[SENTRY_THREAD_SNAPSHOT_NAME_LENGTH - 1] = '\0';
    }
    backend->releaseList(backend->context, list, count);
    output->threads = threads;
    output->count = count;
    return true;
}

void
sentryThreadSnapshotDestroy(
    const SentryThreadSnapshotBackend *backend, SentryThreadSnapshotBuffer *output)
{
    if (output->threads != NULL) {
        backend->deallocate(backend->context, output->threads);
    }
    *output = (SentryThreadSnapshotBuffer) { 0 };
}
#endif
