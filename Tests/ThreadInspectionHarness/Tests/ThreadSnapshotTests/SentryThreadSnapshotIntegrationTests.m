#import "MachCaptureObserver.h"
#import <KSDynamicLinker.h>
#import <KSMachineContext.h>
#import <SentryThreadSnapshot.h>
#import <XCTest/XCTest.h>
#include <pthread.h>
#include <string.h>

typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t condition;
    size_t ready;
    bool stop;
    int stackDepth;
    const char *name;
} WorkerPool;

__attribute__((noinline)) static int
waitAtDepth(WorkerPool *pool, int depth)
{
    if (depth > 0) {
        // A volatile result keeps the recursive frames live even in optimized test builds.
        volatile int result = waitAtDepth(pool, depth - 1);
        return result + 1;
    }
    pthread_mutex_lock(&pool->mutex);
    pool->ready++;
    pthread_cond_broadcast(&pool->condition);
    while (!pool->stop) {
        pthread_cond_wait(&pool->condition, &pool->mutex);
    }
    pthread_mutex_unlock(&pool->mutex);
    return 0;
}

static void *
workerMain(void *context)
{
    WorkerPool *pool = context;
    pthread_setname_np(pool->name != NULL ? pool->name : "snapshot-worker");
    waitAtDepth(pool, pool->stackDepth);
    return NULL;
}

static size_t
startWorkers(WorkerPool *pool, pthread_t *threads, size_t count)
{
    size_t created = 0;
    for (; created < count; created++) {
        if (pthread_create(&threads[created], NULL, workerMain, pool) != 0) {
            break;
        }
    }
    pthread_mutex_lock(&pool->mutex);
    while (pool->ready < created) {
        pthread_cond_wait(&pool->condition, &pool->mutex);
    }
    pthread_mutex_unlock(&pool->mutex);
    return created;
}

static void
stopWorkers(WorkerPool *pool, pthread_t *threads, size_t count)
{
    pthread_mutex_lock(&pool->mutex);
    pool->stop = true;
    pthread_cond_broadcast(&pool->condition);
    pthread_mutex_unlock(&pool->mutex);
    for (size_t i = 0; i < count; i++) {
        pthread_join(threads[i], NULL);
    }
    pthread_cond_destroy(&pool->condition);
    pthread_mutex_destroy(&pool->mutex);
}

static void *
failAllocation(void *context, size_t count, size_t size)
{
    (void)context;
    (void)count;
    (void)size;
    return NULL;
}

@interface SentryThreadSnapshotIntegrationTests : XCTestCase
@end

@implementation SentryThreadSnapshotIntegrationTests

- (void)setUp
{
    [super setUp];
    // Match the installed SDK's initialized unwind-image cache, outside any suspension.
    ksdl_init();
}

- (void)testCapture_whenManyLiveThreads_shouldCaptureAllNonReservedWorkersAndBalanceRights
{
    // -- Arrange --
    WorkerPool pool = { .mutex = PTHREAD_MUTEX_INITIALIZER, .condition = PTHREAD_COND_INITIALIZER };
    pthread_t workers[96];
    size_t count = startWorkers(&pool, workers, 96);
    XCTAssertEqual(count, 96);
    if (count == 0) {
        stopWorkers(&pool, workers, count);
        return;
    }
    thread_t reserved = pthread_mach_thread_np(workers[0]);
    ksmc_addReservedThread(reserved);
    mach_port_urefs_t before[96] = { 0 };
    for (size_t i = 0; i < count; i++) {
        XCTAssertEqual(mach_port_get_refs(mach_task_self(), pthread_mach_thread_np(workers[i]),
                           MACH_PORT_RIGHT_SEND, &before[i]),
            KERN_SUCCESS);
    }
    SentryThreadSnapshotBackend backend = sentryThreadSnapshotKSCrashBackend();
    SentryThreadSnapshotBuffer output;

    // -- Act --
    beginMachCaptureObservation(MACH_PORT_NULL, MACH_PORT_NULL);
    bool success = sentryThreadSnapshotCapture(&backend, true, &output);
    MachCaptureObservation observation = endMachCaptureObservation();

    // -- Assert --
    XCTAssertTrue(success);
    XCTAssertGreaterThan(output.count, 70);
    XCTAssertGreaterThanOrEqual(output.count, count + 1);
    XCTAssertGreaterThanOrEqual(observation.suspensions, count - 1);
    XCTAssertEqual(observation.maxActive, observation.suspensions);
    XCTAssertEqual(observation.active, 0);
    XCTAssertEqual(observation.suspensions, observation.resumptions);
    XCTAssertFalse(observation.touchedReserved);
    XCTAssertFalse(observation.touchedCurrent);
    for (size_t i = 0; i < count; i++) {
        thread_t target = pthread_mach_thread_np(workers[i]);
        bool found = false;
        for (size_t j = 0; j < output.count; j++) {
            const SentryThreadSnapshot *snapshot = &output.threads[j];
            if (snapshot->thread == target) {
                found = true;
                XCTAssertEqual(strcmp(snapshot->name, "snapshot-worker"), 0);
                if (target == reserved) {
                    XCTAssertEqual(snapshot->status, SentryThreadCaptureReserved);
                    XCTAssertEqual(snapshot->frameCount, 0);
                } else {
                    XCTAssertEqual(snapshot->status, SentryThreadCaptureSucceeded);
                    XCTAssertGreaterThan(snapshot->frameCount, 0);
                }
                break;
            }
        }
        XCTAssertTrue(found);
        mach_port_urefs_t after = 0;
        XCTAssertEqual(mach_port_get_refs(mach_task_self(), target, MACH_PORT_RIGHT_SEND, &after),
            KERN_SUCCESS);
        XCTAssertEqual(after, before[i]);
    }
    sentryThreadSnapshotDestroy(&backend, &output);
    stopWorkers(&pool, workers, count);
}

- (void)testCapture_whenAllocationFails_shouldReleaseRealEnumerationRightsWithoutSuspending
{
    // -- Arrange --
    thread_t current = mach_thread_self();
    mach_port_urefs_t before = 0;
    XCTAssertEqual(
        mach_port_get_refs(mach_task_self(), current, MACH_PORT_RIGHT_SEND, &before), KERN_SUCCESS);
    SentryThreadSnapshotBackend backend = sentryThreadSnapshotKSCrashBackend();
    backend.allocate = failAllocation;
    SentryThreadSnapshotBuffer output;

    // -- Act --
    beginMachCaptureObservation(MACH_PORT_NULL, MACH_PORT_NULL);
    bool success = sentryThreadSnapshotCapture(&backend, true, &output);
    MachCaptureObservation observation = endMachCaptureObservation();

    // -- Assert --
    XCTAssertFalse(success);
    XCTAssertEqual(output.count, 0);
    XCTAssertEqual(output.threads, NULL);
    XCTAssertEqual(observation.suspendAttempts, 0);
    mach_port_urefs_t after = 0;
    XCTAssertEqual(
        mach_port_get_refs(mach_task_self(), current, MACH_PORT_RIGHT_SEND, &after), KERN_SUCCESS);
    XCTAssertEqual(after, before);
    mach_port_deallocate(mach_task_self(), current);
}

- (void)testCapture_whenSuspendOrStateReadFails_shouldOnlyResumeSuccessfulSuspensions
{
    // -- Arrange --
    WorkerPool pool = { .mutex = PTHREAD_MUTEX_INITIALIZER, .condition = PTHREAD_COND_INITIALIZER };
    pthread_t workers[1];
    size_t count = startWorkers(&pool, workers, 1);
    XCTAssertEqual(count, 1);
    if (count != 1) {
        stopWorkers(&pool, workers, count);
        return;
    }
    thread_t target = pthread_mach_thread_np(workers[0]);
    SentryThreadSnapshotBackend backend = sentryThreadSnapshotKSCrashBackend();
    SentryThreadSnapshotBuffer suspendFailureOutput;
    SentryThreadSnapshotBuffer stateFailureOutput;

    // -- Act --
    beginMachCaptureObservation(target, MACH_PORT_NULL);
    bool suspendCaptureSucceeded
        = sentryThreadSnapshotCapture(&backend, true, &suspendFailureOutput);
    MachCaptureObservation suspendFailure = endMachCaptureObservation();

    beginMachCaptureObservation(MACH_PORT_NULL, target);
    bool stateCaptureSucceeded = sentryThreadSnapshotCapture(&backend, true, &stateFailureOutput);
    MachCaptureObservation stateFailure = endMachCaptureObservation();

    // -- Assert --
    XCTAssertTrue(suspendCaptureSucceeded);
    XCTAssertEqual(suspendFailure.suspendAttempts, suspendFailure.suspensions + 1);
    XCTAssertEqual(suspendFailure.suspensions, suspendFailure.resumptions);
    XCTAssertEqual(suspendFailure.active, 0);
    XCTAssertTrue(stateCaptureSucceeded);
    XCTAssertEqual(stateFailure.suspensions, stateFailure.resumptions);
    XCTAssertEqual(stateFailure.active, 0);
    bool foundSuspendFailure = false;
    for (size_t i = 0; i < suspendFailureOutput.count; i++) {
        const SentryThreadSnapshot *snapshot = &suspendFailureOutput.threads[i];
        if (snapshot->thread == target) {
            foundSuspendFailure = true;
            XCTAssertFalse(snapshot->wasSuspended);
            XCTAssertEqual(snapshot->status, SentryThreadCaptureUnavailable);
        }
    }
    bool foundStateFailure = false;
    for (size_t i = 0; i < stateFailureOutput.count; i++) {
        const SentryThreadSnapshot *snapshot = &stateFailureOutput.threads[i];
        if (snapshot->thread == target) {
            foundStateFailure = true;
            XCTAssertTrue(snapshot->wasSuspended);
            XCTAssertEqual(snapshot->status, SentryThreadCaptureUnavailable);
            XCTAssertEqual(snapshot->frameCount, 0);
            XCTAssertFalse(snapshot->isTruncated);
        }
    }
    XCTAssertTrue(foundSuspendFailure);
    XCTAssertTrue(foundStateFailure);
    sentryThreadSnapshotDestroy(&backend, &suspendFailureOutput);
    sentryThreadSnapshotDestroy(&backend, &stateFailureOutput);
    stopWorkers(&pool, workers, count);
}

- (void)testCapture_whenStackExceedsLegacyLimit_shouldKeepFramesBeyondOneHundred
{
    // -- Arrange --
    WorkerPool pool = {
        .mutex = PTHREAD_MUTEX_INITIALIZER, .condition = PTHREAD_COND_INITIALIZER, .stackDepth = 150
    };
    pthread_t workers[1];
    size_t count = startWorkers(&pool, workers, 1);
    XCTAssertEqual(count, 1);
    if (count != 1) {
        stopWorkers(&pool, workers, count);
        return;
    }
    thread_t target = pthread_mach_thread_np(workers[0]);
    SentryThreadSnapshotBackend backend = sentryThreadSnapshotKSCrashBackend();
    SentryThreadSnapshotBuffer output;

    // -- Act --
    bool success = sentryThreadSnapshotCapture(&backend, true, &output);
    stopWorkers(&pool, workers, count);

    // -- Assert --
    XCTAssertTrue(success);
    bool found = false;
    for (size_t i = 0; i < output.count; i++) {
        if (output.threads[i].thread == target) {
            found = true;
            XCTAssertEqual(output.threads[i].status, SentryThreadCaptureSucceeded);
            XCTAssertGreaterThan(output.threads[i].frameCount, 100);
            XCTAssertFalse(output.threads[i].isTruncated);
        }
    }
    XCTAssertTrue(found);
    sentryThreadSnapshotDestroy(&backend, &output);
}

- (void)testCapture_whenNameFillsOSField_shouldPreserveCompleteName
{
    // -- Arrange --
    char name[sizeof(((thread_extended_info_data_t *)0)->pth_name)];
    memset(name, 'x', sizeof(name) - 1);
    name[sizeof(name) - 1] = '\0';
    WorkerPool pool = {
        .mutex = PTHREAD_MUTEX_INITIALIZER, .condition = PTHREAD_COND_INITIALIZER, .name = name
    };
    pthread_t workers[1];
    size_t count = startWorkers(&pool, workers, 1);
    XCTAssertEqual(count, 1);
    if (count != 1) {
        stopWorkers(&pool, workers, count);
        return;
    }
    thread_t target = pthread_mach_thread_np(workers[0]);
    SentryThreadSnapshotBackend backend = sentryThreadSnapshotKSCrashBackend();
    SentryThreadSnapshotBuffer output;

    // -- Act --
    bool success = sentryThreadSnapshotCapture(&backend, false, &output);
    stopWorkers(&pool, workers, count);

    // -- Assert --
    XCTAssertTrue(success);
    bool found = false;
    for (size_t i = 0; i < output.count; i++) {
        if (output.threads[i].thread == target) {
            found = true;
            XCTAssertEqual(strcmp(output.threads[i].name, name), 0);
        }
    }
    XCTAssertTrue(found);
    sentryThreadSnapshotDestroy(&backend, &output);
}

- (void)testCapture_whenStackExceedsFrameLimit_shouldBoundWritesAndReportTruncation
{
    // -- Arrange --
    WorkerPool pool = { .mutex = PTHREAD_MUTEX_INITIALIZER,
        .condition = PTHREAD_COND_INITIALIZER,
        .stackDepth = SENTRY_THREAD_SNAPSHOT_MAX_FRAMES + 50 };
    pthread_t workers[1];
    size_t count = startWorkers(&pool, workers, 1);
    XCTAssertEqual(count, 1);
    if (count != 1) {
        stopWorkers(&pool, workers, count);
        return;
    }
    SentryThreadSnapshotBackend backend = sentryThreadSnapshotKSCrashBackend();
    struct {
        uintptr_t before;
        uintptr_t addresses[SENTRY_THREAD_SNAPSHOT_MAX_FRAMES];
        uintptr_t after;
    } storage = { .before = 1234, .after = 5678 };
    bool truncated = false;

    // -- Act --
    beginMachCaptureObservation(MACH_PORT_NULL, MACH_PORT_NULL);
    thread_t target = pthread_mach_thread_np(workers[0]);
    bool didSuspend = backend.suspend(backend.context, target);
    size_t frames = didSuspend
        ? backend.captureSuspended(backend.context, target, storage.addresses,
              SENTRY_THREAD_SNAPSHOT_MAX_FRAMES, &truncated)
        : 0;
    if (didSuspend) {
        backend.resume(backend.context, target);
    }
    MachCaptureObservation observation = endMachCaptureObservation();
    stopWorkers(&pool, workers, count);

    // -- Assert --
    XCTAssertEqual(frames, SENTRY_THREAD_SNAPSHOT_MAX_FRAMES);
    XCTAssertTrue(truncated);
    XCTAssertEqual(storage.before, 1234);
    XCTAssertEqual(storage.after, 5678);
    XCTAssertEqual(observation.suspensions, 1);
    XCTAssertEqual(observation.resumptions, 1);
    XCTAssertEqual(observation.active, 0);
}

- (void)testCapture_whenEnumeratedThreadExits_shouldFailSafelyAndReleaseItsDeadName
{
    // -- Arrange --
    WorkerPool pool = { .mutex = PTHREAD_MUTEX_INITIALIZER, .condition = PTHREAD_COND_INITIALIZER };
    pthread_t workers[1];
    size_t count = startWorkers(&pool, workers, 1);
    XCTAssertEqual(count, 1);
    if (count != 1) {
        stopWorkers(&pool, workers, count);
        return;
    }
    thread_t target = pthread_mach_thread_np(workers[0]);
    SentryThreadSnapshotBackend backend = sentryThreadSnapshotKSCrashBackend();
    void *list = NULL;
    size_t threadCount = 0;
    bool enumerated = backend.enumerate(backend.context, &list, &threadCount);
    stopWorkers(&pool, workers, count);
    XCTAssertTrue(enumerated);
    if (!enumerated) {
        return;
    }
    uintptr_t addresses[SENTRY_THREAD_SNAPSHOT_MAX_FRAMES];
    bool truncated = true;
    char name[SENTRY_THREAD_SNAPSHOT_NAME_LENGTH] = { 0 };

    // -- Act --
    beginMachCaptureObservation(MACH_PORT_NULL, MACH_PORT_NULL);
    bool didSuspend = backend.suspend(backend.context, target);
    size_t frameCount = didSuspend ? backend.captureSuspended(backend.context, target, addresses,
                                         SENTRY_THREAD_SNAPSHOT_MAX_FRAMES, &truncated)
                                   : 0;
    if (didSuspend) {
        backend.resume(backend.context, target);
    }
    MachCaptureObservation observation = endMachCaptureObservation();
    bool named = backend.name(backend.context, target, name, sizeof(name));
    backend.releaseList(backend.context, list, threadCount);

    // -- Assert --
    XCTAssertEqual(frameCount, 0);
    // A failed suspend skips capture, so the capture callback does not own this output parameter.
    XCTAssertTrue(truncated);
    XCTAssertFalse(named);
    XCTAssertEqual(observation.suspendAttempts, 1);
    XCTAssertEqual(observation.suspensions, 0);
    XCTAssertEqual(observation.resumptions, 0);
    mach_port_type_t type = 0;
    XCTAssertEqual(mach_port_type(mach_task_self(), target, &type), KERN_INVALID_NAME);
}

@end
