#ifndef SENTRY_THREAD_SNAPSHOT_H
#define SENTRY_THREAD_SNAPSHOT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Maximum number of instruction addresses stored for a remote thread.
 *
 * This mirrors KSCrash's `KSSC_MAX_STACK_DEPTH`, not an independent SDK policy. KSCrash may probe
 * one additional frame to report truncation, but never writes it to this array. Its separate
 * stack-overflow classification threshold does not limit capture. Current-thread capture uses a
 * different KSCrash path and bound. The KSCrash adapter statically verifies this value.
 */
#define SENTRY_THREAD_SNAPSHOT_MAX_FRAMES 512

/**
 * Storage size in bytes for a copied thread name, including its NUL terminator.
 *
 * This mirrors Darwin's `thread_extended_info_data_t.pth_name` (`MAXTHREADNAMESIZE`), allowing at
 * most 63 name bytes. The KSCrash adapter statically verifies this value.
 */
#define SENTRY_THREAD_SNAPSHOT_NAME_LENGTH 64

/** Describes the final stack-capture result for one enumerated thread. */
typedef enum {
    /** Stack capture was disabled by the caller or SDK readiness policy. */
    SentryThreadCaptureNotRequested,
    /** The current thread is delegated to the SDK's current-thread stack provider. */
    SentryThreadCaptureCurrent,
    /** The backend identified this as an infrastructure thread that must not be suspended. */
    SentryThreadCaptureReserved,
    /** No remote frames are available; `wasSuspended` indicates whether unwind was attempted. */
    SentryThreadCaptureUnavailable,
    /** Remote capture produced one or more instruction addresses. */
    SentryThreadCaptureSucceeded,
} SentryThreadCaptureStatus;

/** Metadata and optional remote stack for one enumerated thread. */
typedef struct {
    /** Backend identity. The record does not retain an associated thread right or lifetime. */
    uintptr_t thread;
    /** Zero-based enumeration ordinal, kept separate because existing event IDs use this value. */
    size_t index;
    bool isMain;
    bool isCurrent;
    SentryThreadCaptureStatus status;
    /**
     * True exactly when `suspend` succeeded. In that case `captureSuspended` and the balancing
     * `resume` were each called once before capture returned. For an unavailable stack, this
     * distinguishes a failed unwind from admission or suspension failure.
     */
    bool wasSuspended;
    /** Truncation reported by the backend for an attempted remote unwind. */
    bool isTruncated;
    /** Number of valid addresses; never exceeds the array capacity and is nonzero on success. */
    size_t frameCount;
    /** Valid prefix is ordered youngest to oldest; model conversion reverses it after capture. */
    uintptr_t addresses[SENTRY_THREAD_SNAPSHOT_MAX_FRAMES];
    /** Always NUL-terminated after successful enumeration; empty when name lookup fails. */
    char name[SENTRY_THREAD_SNAPSHOT_NAME_LENGTH];
} SentryThreadSnapshot;

/** Owned array returned by capture. A zero count has a NULL `threads` pointer. */
typedef struct {
    size_t count;
    SentryThreadSnapshot *threads;
} SentryThreadSnapshotBuffer;

/**
 * Process-wide, nonblocking admission shared by nonfatal bulk inspection and profiling.
 *
 * Acquisition returns immediately. Remote-suspension paths acquire before their first suspension.
 * A caller that acquires admission must release it exactly once, after its final balancing resume
 * attempt. A contender must skip remote suspension rather than wait because the current owner may
 * already have suspended the contending thread.
 */
bool sentryThreadSuspensionTryAcquire(void);
void sentryThreadSuspensionRelease(void);

/**
 * C-only backend interface; no backend-specific type crosses the snapshot boundary.
 *
 * All callbacks except `canCapture` are required. A successful `enumerate` transfers ownership of
 * its list to the driver, which calls `releaseList` exactly once on every later path, including
 * size or allocation failure. A failed `enumerate` transfers no ownership. Identities returned by
 * `threadAt` must remain valid until `releaseList`.
 *
 * The driver has three callback phases:
 *
 * 1. Prepare: enumerate, allocate, evaluate policy, and resolve thread metadata.
 * 2. Suspend: call only suspend, captureSuspended, and resume from the first successful suspension
 *    through the final balancing resume attempt. These callbacks must not allocate, message
 *    Objective-C or Swift, or acquire a blocking lock.
 * 3. Finish: copy names and release the enumeration list after admission has been released.
 *
 * A successful `suspend` transfers one suspension to the driver. The driver calls
 * `captureSuspended` once and `resume` once for that target, even when unwind fails.
 * `captureSuspended` must not change suspension counts or write more than `capacity` addresses;
 * return values above `capacity` are treated as capture failure. `name` must not write more than
 * its capacity. Memory returned by `allocate` is later passed to `deallocate` with the same
 * context.
 */
typedef struct {
    void *context;
    bool (*enumerate)(void *context, void **list, size_t *count);
    void (*releaseList)(void *context, void *list, size_t count);
    uintptr_t (*threadAt)(void *context, void *list, size_t index);
    uintptr_t (*currentThread)(void *context);
    uintptr_t (*mainThread)(void *context);
    /** Optional readiness policy, evaluated after enumeration and before any suspension. */
    bool (*canCapture)(void *context);
    bool (*isReserved)(void *context, uintptr_t thread);
    bool (*suspend)(void *context, uintptr_t thread);
    size_t (*captureSuspended)(
        void *context, uintptr_t thread, uintptr_t *addresses, size_t capacity, bool *isTruncated);
    void (*resume)(void *context, uintptr_t thread);
    bool (*name)(void *context, uintptr_t thread, char *buffer, size_t capacity);
    void *(*allocate)(void *context, size_t count, size_t size);
    void (*deallocate)(void *context, void *allocation);
} SentryThreadSnapshotBackend;

/**
 * Captures one record for every thread returned by the backend, without a fixed thread-count limit.
 *
 * Preparation and allocation finish before any suspension. When stacks are enabled, the driver
 * tries process-wide admission without waiting, suspends each eligible remote target sequentially,
 * unwinds every successfully suspended target while that set remains stopped, and then attempts
 * every balancing resume before releasing admission. Name lookup and result consumption happen
 * afterward.
 *
 * Suspension is not atomic: the current thread, reserved threads, targets that fail to suspend,
 * threads created after enumeration, and external activity may continue running. Every unwind is
 * therefore best effort from an arbitrary instruction boundary.
 *
 * Returns false only for enumeration, result-size, or allocation failure; `output` is then empty.
 * Per-thread suspension and unwind failures still return a record with the corresponding status;
 * name failure leaves the record's name empty. A successful empty enumeration does not allocate.
 * The caller owns a successful output until `sentryThreadSnapshotDestroy` and must pass the same
 * backend allocator and context. On entry, `output` must not own an existing buffer.
 */
bool sentryThreadSnapshotCapture(const SentryThreadSnapshotBackend *backend, bool captureStacks,
    SentryThreadSnapshotBuffer *output);

/** Releases an owned output buffer and resets it to empty. Safe to call on an empty buffer. */
void sentryThreadSnapshotDestroy(
    const SentryThreadSnapshotBackend *backend, SentryThreadSnapshotBuffer *output);

/**
 * Returns the raw KSCrash backend without SDK installation-readiness policy.
 *
 * Intended for C contract tests and callers that independently ensure monitor installation cannot
 * race reserved-thread discovery.
 */
SentryThreadSnapshotBackend sentryThreadSnapshotKSCrashBackend(void);

/**
 * SDK capture entry point using the KSCrash backend and process-lifetime readiness policy.
 *
 * Readiness is evaluated after enumeration. If remote capture is unsafe, capture still succeeds
 * with thread metadata but does not attempt remote suspension. Callers may consume names, records,
 * and models only after this function returns.
 */
bool sentryThreadSnapshotSystemCapture(
    bool captureStacks, bool requiresCrashHandler, SentryThreadSnapshotBuffer *output);

/** Releases an SDK capture buffer and resets it to empty. */
void sentryThreadSnapshotSystemDestroy(SentryThreadSnapshotBuffer *output);

/** Copies the kernel thread name into `buffer`; returns false when it cannot be read. */
bool sentryThreadSnapshotCopyName(uintptr_t thread, char *buffer, size_t capacity);

/** Returns the backend identity for the calling thread without inspecting its stack. */
uintptr_t sentryThreadInspectionCurrentThread(void);

/**
 * Publishes serialized crash-handler installation state to remote capture.
 *
 * The installer calls `WillInstall` immediately before each attempt and `DidInstall` afterward. A
 * failed initial installation restores the not-installed state. Successful installation is
 * process-lifetime state and must survive SDK close because KSCrash remains installed across SDK
 * lifecycles.
 */
void sentryThreadInspectionWillInstallCrashHandler(void);
void sentryThreadInspectionDidInstallCrashHandler(bool succeeded);

/**
 * Returns whether remote capture is safe for the caller's crash-handler requirement.
 *
 * Capture is allowed after successful installation. Before installation it is allowed only when
 * the caller does not require a crash handler. It is always rejected while installation is active.
 */
bool sentryThreadInspectionCanCaptureRemote(bool requiresCrashHandler);

#ifdef __cplusplus
}
#endif
#endif
