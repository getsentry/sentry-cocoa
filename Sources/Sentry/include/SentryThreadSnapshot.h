#ifndef SENTRY_THREAD_SNAPSHOT_H
#define SENTRY_THREAD_SNAPSHOT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// These are backend storage bounds, not independent SDK policy. They are mirrored here to keep
// backend headers/types out of the neutral boundary. The adapter statically checks both values;
// update these mirrors with the backend if those checks fail after an upgrade.

// Source: KSCrashRecordingCore/include/KSStackCursor.h, KSSC_MAX_STACK_DEPTH.
// KSBacktrace.c clamps remote-thread capture to 512 addresses. Its truncation check probes one
// additional frame without writing it into the output buffer. This is NOT the separate 150-frame
// KSSC_STACK_OVERFLOW_THRESHOLD classification, which does not stop the walk. Current-thread
// capture uses KSCrash's self-thread cursor and its own internal storage bound instead.
#define SENTRY_THREAD_SNAPSHOT_MAX_FRAMES 512

// Source: Darwin <mach/thread_info.h>, thread_extended_info_data_t.pth_name (MAXTHREADNAMESIZE).
// The 64-byte field includes the NUL terminator: at most 63 name bytes, not 63 Unicode characters.
// XNU bsd/kern/proc_info.c (PROC_SELFSET_THREADNAME) rejects longer pthread_setname_np requests
// with ENAMETOOLONG rather than truncating them. libpthread/src/pthread.c updates its same-sized
// cached name only after the kernel accepts the name, so this field holds the complete pthread
// name; there is no longer cached pthread name to recover. Failed setters leave the old name
// intact.
#define SENTRY_THREAD_SNAPSHOT_NAME_LENGTH 64

typedef enum {
    SentryThreadCaptureNotRequested,
    SentryThreadCaptureCurrent,
    SentryThreadCaptureReserved,
    SentryThreadCaptureUnavailable,
    SentryThreadCaptureSucceeded,
} SentryThreadCaptureStatus;

typedef struct {
    uintptr_t thread;
    // Preserve enumeration ordinal separately from the Mach identity. Existing event IDs use it.
    size_t index;
    bool isMain;
    bool isCurrent;
    SentryThreadCaptureStatus status;
    // True when this inspection successfully acquired a suspension. Retained as capture metadata;
    // the driver always makes one balancing resume attempt before returning.
    bool wasSuspended;
    bool isTruncated;
    size_t frameCount;
    // Youngest to oldest. Model conversion/reversal happens after capture returns.
    uintptr_t addresses[SENTRY_THREAD_SNAPSHOT_MAX_FRAMES];
    char name[SENTRY_THREAD_SNAPSHOT_NAME_LENGTH];
} SentryThreadSnapshot;

typedef struct {
    size_t count;
    SentryThreadSnapshot *threads;
} SentryThreadSnapshotBuffer;

// Process-wide, nonblocking admission shared by the SDK's nonfatal bulk-inspection and profiler
// suspension paths. An owner acquires before its first thread_suspend and releases only after its
// final balancing thread_resume attempt. Contenders must skip remote capture rather than wait: the
// owner may have suspended them.
bool sentryThreadSuspensionTryAcquire(void);
void sentryThreadSuspensionRelease(void);

// C-only backend seam. No backend types cross this boundary.
// Successful enumerate owns its list until releaseList, including on allocation/size failure.
// Failed enumerate must not transfer any ownership.
// threadAt returns an identity kept alive by that list. The driver resolves all identities,
// metadata, policy, and reserved-thread membership before suspending anything. From the first
// successful suspend through the final resume attempt it calls only suspend, captureSuspended, and
// resume; those callbacks may not allocate, message ObjC/Swift, or acquire blocking locks.
// captureSuspended must not change the target's suspension count. resume is called exactly once for
// each successful suspend, including when unwinding fails. Caller serializes captures and must not
// enter while another environment is suspended by this inspection path.
typedef struct {
    void *context;
    bool (*enumerate)(void *context, void **list, size_t *count);
    void (*releaseList)(void *context, void *list, size_t count);
    uintptr_t (*threadAt)(void *context, void *list, size_t index);
    uintptr_t (*currentThread)(void *context);
    uintptr_t (*mainThread)(void *context);
    // Optional startup policy, evaluated AFTER enumeration and BEFORE any target suspension.
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

// Output is empty on failure. An empty successful enumeration does not allocate.
// Each record remains present even if capture fails or is skipped. No fixed thread-count cutoff.
// A process-wide admission contender retains records but does not attempt remote suspension.
// Otherwise, eligible targets are suspended sequentially, then all successfully suspended targets
// are unwound while that set remains stopped, and finally each acquired suspension is balanced.
// This is not literally atomic: the inspecting/current thread, reserved threads, failed targets,
// and targets not present in the enumeration can continue running. Every unwind is best effort from
// an arbitrary instruction boundary. The caller owns output until destroy, using the same backend
// allocator pair. Output must not already own a buffer. Raw KSCrash callers must coordinate monitor
// installation themselves. SDK callers use SystemCapture below: it checks readiness after
// enumeration and falls back to metadata/current-thread-only capture while the required
// installation is pending.
bool sentryThreadSnapshotCapture(const SentryThreadSnapshotBackend *backend, bool captureStacks,
    SentryThreadSnapshotBuffer *output);
void sentryThreadSnapshotDestroy(
    const SentryThreadSnapshotBackend *backend, SentryThreadSnapshotBuffer *output);

// Raw backend for C contract tests; callers must observe the installation precondition above.
SentryThreadSnapshotBackend sentryThreadSnapshotKSCrashBackend(void);

// SDK entry points. Names and result/model consumption must occur outside any owned suspension.
bool sentryThreadSnapshotSystemCapture(
    bool captureStacks, bool requiresCrashHandler, SentryThreadSnapshotBuffer *output);
void sentryThreadSnapshotSystemDestroy(SentryThreadSnapshotBuffer *output);
bool sentryThreadSnapshotCopyName(uintptr_t thread, char *buffer, size_t capacity);
// Narrow current-thread identity capability for consumers that do not inspect stacks.
uintptr_t sentryThreadInspectionCurrentThread(void);

// Serialized installer lifecycle. Successful publication has process lifetime: SDK close() must
// not clear it because the KSCrash recorder remains installed across SDK lifecycles.
void sentryThreadInspectionWillInstallCrashHandler(void);
void sentryThreadInspectionDidInstallCrashHandler(bool succeeded);
bool sentryThreadInspectionCanCaptureRemote(bool requiresCrashHandler);

#ifdef __cplusplus
}
#endif
#endif
