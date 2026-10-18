#import <SentryThreadSnapshot.h>
#import <XCTest/XCTest.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    size_t count;
    size_t releases;
    size_t allocations;
    size_t deallocations;
    size_t suspendAttempts;
    size_t suspensions;
    size_t captures;
    size_t resumes;
    size_t activeSuspensions;
    size_t activeAtFirstCapture;
    size_t names;
    size_t accesses;
    bool failEnumeration;
    bool failAllocation;
    bool unsafeCallback;
    bool badCaptureCount;
    bool longName;
    bool blockDuringEnumeration;
    bool enumerationComplete;
    bool checkedCapturePolicy;
    uintptr_t failSuspend;
    uintptr_t failCapture;
    uintptr_t failName;
    atomic_bool *suspensionEntered;
    atomic_bool *continueSuspension;
} Fixture;

static void
checkResumed(Fixture *fixture)
{
    fixture->unsafeCallback |= fixture->activeSuspensions != 0;
}

static bool
enumerate(void *context, void **list, size_t *count)
{
    Fixture *fixture = context;
    checkResumed(fixture);
    if (fixture->failEnumeration) {
        return false;
    }
    *list = fixture;
    *count = fixture->count;
    fixture->enumerationComplete = true;
    return true;
}

static void
releaseList(void *context, void *list, size_t count)
{
    Fixture *fixture = context;
    checkResumed(fixture);
    fixture->unsafeCallback |= list != fixture || count != fixture->count;
    fixture->releases++;
}

static uintptr_t
threadAt(void *context, void *list, size_t index)
{
    Fixture *fixture = context;
    checkResumed(fixture);
    fixture->unsafeCallback |= list != fixture || index >= fixture->count;
    fixture->accesses++;
    return index + 1;
}

static uintptr_t
currentThread(void *context)
{
    checkResumed(context);
    return 1;
}

static uintptr_t
mainThread(void *context)
{
    checkResumed(context);
    return 3;
}

static bool
canCapture(void *context)
{
    Fixture *fixture = context;
    checkResumed(fixture);
    fixture->checkedCapturePolicy = true;
    fixture->unsafeCallback |= !fixture->enumerationComplete;
    return !(fixture->enumerationComplete && fixture->blockDuringEnumeration);
}

static bool
isReserved(void *context, uintptr_t thread)
{
    checkResumed(context);
    return thread == 2;
}

static bool
suspendThread(void *context, uintptr_t thread)
{
    Fixture *fixture = context;
    fixture->unsafeCallback
        |= thread == 1 || thread == 2 || fixture->captures != 0 || fixture->resumes != 0;
    fixture->suspendAttempts++;
    if (fixture->failSuspend == thread) {
        return false;
    }
    fixture->suspensions++;
    fixture->activeSuspensions++;
    if (fixture->suspensionEntered != NULL && fixture->suspensions == 1) {
        // Test-only fake suspension: open a deterministic overlap without stopping an OS thread.
        atomic_store_explicit(fixture->suspensionEntered, true, memory_order_release);
        while (!atomic_load_explicit(fixture->continueSuspension, memory_order_acquire)) { }
    }
    return true;
}

static size_t
captureSuspended(
    void *context, uintptr_t thread, uintptr_t *addresses, size_t capacity, bool *isTruncated)
{
    Fixture *fixture = context;
    fixture->unsafeCallback |= thread == 1 || thread == 2 || fixture->activeSuspensions == 0
        || fixture->resumes != 0 || fixture->captures >= fixture->suspensions;
    if (fixture->captures == 0) {
        fixture->activeAtFirstCapture = fixture->activeSuspensions;
    }
    fixture->captures++;
    if (fixture->failCapture == thread) {
        return 0;
    }
    for (size_t i = 0; i < capacity; i++) {
        addresses[i] = thread * 1000 + i;
    }
    *isTruncated = true;
    return fixture->badCaptureCount ? capacity + 1 : capacity;
}

static void
resumeThread(void *context, uintptr_t thread)
{
    Fixture *fixture = context;
    fixture->unsafeCallback |= thread == 1 || thread == 2 || fixture->activeSuspensions == 0
        || fixture->captures != fixture->suspensions;
    fixture->resumes++;
    fixture->activeSuspensions--;
}

static bool
name(void *context, uintptr_t thread, char *buffer, size_t capacity)
{
    Fixture *fixture = context;
    checkResumed(fixture);
    fixture->names++;
    if (fixture->longName || fixture->failName == thread) {
        memset(buffer, 'x', capacity);
    } else {
        strlcpy(buffer, "worker", capacity);
    }
    return fixture->failName != thread;
}

static void *
allocate(void *context, size_t count, size_t size)
{
    Fixture *fixture = context;
    checkResumed(fixture);
    fixture->allocations++;
    return fixture->failAllocation ? NULL : calloc(count, size);
}

static void
deallocate(void *context, void *allocation)
{
    Fixture *fixture = context;
    checkResumed(fixture);
    fixture->deallocations++;
    free(allocation);
}

static SentryThreadSnapshotBackend
backendFor(Fixture *fixture)
{
    return (SentryThreadSnapshotBackend) {
        .context = fixture,
        .enumerate = enumerate,
        .releaseList = releaseList,
        .threadAt = threadAt,
        .currentThread = currentThread,
        .mainThread = mainThread,
        .canCapture = canCapture,
        .isReserved = isReserved,
        .suspend = suspendThread,
        .captureSuspended = captureSuspended,
        .resume = resumeThread,
        .name = name,
        .allocate = allocate,
        .deallocate = deallocate,
    };
}

typedef struct {
    Fixture *fixture;
    bool succeeded;
    SentryThreadSnapshotBuffer output;
} ConcurrentCapture;

static void *
captureOnThread(void *context)
{
    ConcurrentCapture *capture = context;
    SentryThreadSnapshotBackend backend = backendFor(capture->fixture);
    capture->succeeded = sentryThreadSnapshotCapture(&backend, true, &capture->output);
    return NULL;
}

@interface SentryThreadSnapshotTests : XCTestCase
@end

@implementation SentryThreadSnapshotTests

- (void)testCapture_whenInstallationStartsDuringEnumeration_shouldKeepMetadataWithoutSuspending
{
    // -- Arrange --
    Fixture fixture = { .count = 160, .blockDuringEnumeration = true };
    SentryThreadSnapshotBackend backend = backendFor(&fixture);
    SentryThreadSnapshotBuffer output;

    // -- Act --
    bool success = sentryThreadSnapshotCapture(&backend, true, &output);

    // -- Assert --
    XCTAssertTrue(success);
    XCTAssertEqual(output.count, 160);
    XCTAssertTrue(fixture.checkedCapturePolicy);
    XCTAssertFalse(fixture.unsafeCallback);
    XCTAssertEqual(fixture.captures, 0);
    XCTAssertEqual(fixture.names, 160);
    for (size_t i = 0; i < output.count; i++) {
        XCTAssertEqual(output.threads[i].status, SentryThreadCaptureNotRequested);
    }
    sentryThreadSnapshotDestroy(&backend, &output);
}

- (void)testCapture_whenIndependentCaptureOwnsSuspension_shouldRejectContenderBeforeSuspending
{
    // -- Arrange --
    atomic_bool suspensionEntered;
    atomic_bool continueSuspension;
    atomic_init(&suspensionEntered, false);
    atomic_init(&continueSuspension, false);
    Fixture ownerFixture = { .count = 5,
        .suspensionEntered = &suspensionEntered,
        .continueSuspension = &continueSuspension };
    Fixture contenderFixture = { .count = 5 };
    ConcurrentCapture owner = { .fixture = &ownerFixture };
    pthread_t ownerThread;
    int createResult = pthread_create(&ownerThread, NULL, captureOnThread, &owner);
    XCTAssertEqual(createResult, 0);
    if (createResult != 0) {
        return;
    }
    while (!atomic_load_explicit(&suspensionEntered, memory_order_acquire)) { }
    SentryThreadSnapshotBackend contenderBackend = backendFor(&contenderFixture);
    SentryThreadSnapshotBuffer contenderOutput;

    // -- Act --
    bool contenderSucceeded
        = sentryThreadSnapshotCapture(&contenderBackend, true, &contenderOutput);
    atomic_store_explicit(&continueSuspension, true, memory_order_release);
    int joinResult = pthread_join(ownerThread, NULL);

    // -- Assert --
    XCTAssertEqual(joinResult, 0);
    XCTAssertTrue(owner.succeeded);
    XCTAssertTrue(contenderSucceeded);
    XCTAssertEqual(ownerFixture.suspensions, 3);
    XCTAssertEqual(ownerFixture.resumes, 3);
    XCTAssertEqual(contenderFixture.suspendAttempts, 0);
    XCTAssertEqual(contenderFixture.captures, 0);
    XCTAssertEqual(contenderFixture.resumes, 0);
    XCTAssertEqual(contenderFixture.names, 5);
    XCTAssertEqual(contenderOutput.count, 5);
    for (size_t i = 0; i < contenderOutput.count; i++) {
        XCTAssertEqual(contenderOutput.threads[i].frameCount, 0);
    }
    bool reacquiredAdmission = sentryThreadSuspensionTryAcquire();
    XCTAssertTrue(reacquiredAdmission);
    if (reacquiredAdmission) {
        sentryThreadSuspensionRelease();
    }
    sentryThreadSnapshotDestroy(&contenderBackend, &contenderOutput);
    SentryThreadSnapshotBackend ownerBackend = backendFor(&ownerFixture);
    sentryThreadSnapshotDestroy(&ownerBackend, &owner.output);
}

- (void)testCapture_whenMoreThanSeventyThreads_shouldKeepEveryRecordAndSkipCurrentAndReserved
{
    // -- Arrange --
    Fixture fixture = { .count = 160 };
    SentryThreadSnapshotBackend backend = backendFor(&fixture);
    SentryThreadSnapshotBuffer output;

    // -- Act --
    bool success = sentryThreadSnapshotCapture(&backend, true, &output);

    // -- Assert --
    XCTAssertTrue(success);
    XCTAssertEqual(output.count, 160);
    XCTAssertEqual(fixture.suspendAttempts, 158);
    XCTAssertEqual(fixture.suspensions, 158);
    XCTAssertEqual(fixture.activeAtFirstCapture, 158);
    XCTAssertEqual(fixture.captures, 158);
    XCTAssertEqual(fixture.resumes, 158);
    XCTAssertEqual(fixture.activeSuspensions, 0);
    XCTAssertEqual(fixture.names, 160);
    XCTAssertEqual(fixture.releases, 1);
    XCTAssertEqual(fixture.allocations, 1);
    if (output.count == 160) {
        XCTAssertEqual(output.threads[0].status, SentryThreadCaptureCurrent);
        XCTAssertTrue(output.threads[0].isCurrent);
        XCTAssertFalse(output.threads[0].isMain);
        XCTAssertEqual(output.threads[1].status, SentryThreadCaptureReserved);
        XCTAssertFalse(output.threads[1].wasSuspended);
        XCTAssertEqual(output.threads[1].frameCount, 0);
        XCTAssertTrue(output.threads[2].isMain);
        XCTAssertFalse(output.threads[2].isCurrent);
        XCTAssertEqual(output.threads[159].thread, 160);
        XCTAssertEqual(output.threads[159].index, 159);
    }
    sentryThreadSnapshotDestroy(&backend, &output);
    sentryThreadSnapshotDestroy(&backend, &output);
    XCTAssertEqual(fixture.deallocations, 1);
    XCTAssertEqual(output.count, 0);
    XCTAssertEqual(output.threads, NULL);
    XCTAssertFalse(fixture.unsafeCallback);
}

- (void)testCapture_whenEmpty_shouldReleaseListWithoutAllocating
{
    // -- Arrange --
    Fixture fixture = { 0 };
    SentryThreadSnapshotBackend backend = backendFor(&fixture);
    SentryThreadSnapshotBuffer output;

    // -- Act --
    bool success = sentryThreadSnapshotCapture(&backend, true, &output);

    // -- Assert --
    XCTAssertTrue(success);
    XCTAssertEqual(output.count, 0);
    XCTAssertEqual(output.threads, NULL);
    XCTAssertEqual(fixture.allocations, 0);
    XCTAssertEqual(fixture.releases, 1);
    XCTAssertEqual(fixture.captures, 0);
}

- (void)testCapture_whenEnumerationFails_shouldReturnEmptyWithoutReleasingUnownedList
{
    // -- Arrange --
    Fixture fixture = { .failEnumeration = true };
    SentryThreadSnapshotBackend backend = backendFor(&fixture);
    SentryThreadSnapshotBuffer output;

    // -- Act --
    bool success = sentryThreadSnapshotCapture(&backend, true, &output);

    // -- Assert --
    XCTAssertFalse(success);
    XCTAssertEqual(output.count, 0);
    XCTAssertEqual(output.threads, NULL);
    XCTAssertEqual(fixture.releases, 0);
    XCTAssertEqual(fixture.allocations, 0);
}

- (void)testCapture_whenAllocationFails_shouldReleaseListWithoutCapturing
{
    // -- Arrange --
    Fixture fixture = { .count = 160, .failAllocation = true };
    SentryThreadSnapshotBackend backend = backendFor(&fixture);
    SentryThreadSnapshotBuffer output;

    // -- Act --
    bool success = sentryThreadSnapshotCapture(&backend, true, &output);

    // -- Assert --
    XCTAssertFalse(success);
    XCTAssertEqual(output.count, 0);
    XCTAssertEqual(output.threads, NULL);
    XCTAssertEqual(fixture.allocations, 1);
    XCTAssertEqual(fixture.releases, 1);
    XCTAssertEqual(fixture.accesses, 0);
    XCTAssertEqual(fixture.captures, 0);
    XCTAssertFalse(fixture.unsafeCallback);
}

- (void)testCapture_whenResultSizeOverflows_shouldReleaseListBeforeAccessOrAllocation
{
    // -- Arrange --
    Fixture fixture = { .count = SIZE_MAX / sizeof(SentryThreadSnapshot) + 1 };
    SentryThreadSnapshotBackend backend = backendFor(&fixture);
    SentryThreadSnapshotBuffer output;

    // -- Act --
    bool success = sentryThreadSnapshotCapture(&backend, true, &output);

    // -- Assert --
    XCTAssertFalse(success);
    XCTAssertEqual(output.count, 0);
    XCTAssertEqual(output.threads, NULL);
    XCTAssertEqual(fixture.allocations, 0);
    XCTAssertEqual(fixture.accesses, 0);
    XCTAssertEqual(fixture.releases, 1);
    XCTAssertFalse(fixture.unsafeCallback);
}

- (void)testCapture_whenStacksNotRequested_shouldOnlyEnumerateAndName
{
    // -- Arrange --
    Fixture fixture = { .count = 160 };
    SentryThreadSnapshotBackend backend = backendFor(&fixture);
    SentryThreadSnapshotBuffer output;

    // -- Act --
    bool success = sentryThreadSnapshotCapture(&backend, false, &output);

    // -- Assert --
    XCTAssertTrue(success);
    XCTAssertEqual(output.count, 160);
    XCTAssertEqual(fixture.captures, 0);
    XCTAssertEqual(fixture.names, 160);
    for (size_t i = 0; i < output.count; i++) {
        XCTAssertEqual(output.threads[i].status, SentryThreadCaptureNotRequested);
        XCTAssertEqual(output.threads[i].frameCount, 0);
    }
    sentryThreadSnapshotDestroy(&backend, &output);
}

- (void)testCapture_whenSuspendAndUnwindFail_shouldExcludeUnsuspendedTargetAndResumeTheRest
{
    // -- Arrange --
    Fixture fixture = { .count = 5, .failSuspend = 3, .failCapture = 4, .failName = 3 };
    SentryThreadSnapshotBackend backend = backendFor(&fixture);
    SentryThreadSnapshotBuffer output;

    // -- Act --
    bool success = sentryThreadSnapshotCapture(&backend, true, &output);

    // -- Assert --
    XCTAssertTrue(success);
    XCTAssertEqual(output.count, 5);
    XCTAssertEqual(fixture.suspendAttempts, 3);
    XCTAssertEqual(fixture.suspensions, 2);
    XCTAssertEqual(fixture.activeAtFirstCapture, 2);
    XCTAssertEqual(fixture.captures, 2);
    XCTAssertEqual(fixture.resumes, 2);
    XCTAssertEqual(fixture.activeSuspensions, 0);
    if (output.count == 5) {
        XCTAssertEqual(output.threads[2].status, SentryThreadCaptureUnavailable);
        XCTAssertFalse(output.threads[2].wasSuspended);
        XCTAssertEqual(output.threads[2].frameCount, 0);
        XCTAssertTrue(output.threads[2].isMain);
        XCTAssertEqual(output.threads[2].name[0], '\0');
        XCTAssertEqual(output.threads[3].status, SentryThreadCaptureUnavailable);
        XCTAssertTrue(output.threads[3].wasSuspended);
        XCTAssertEqual(output.threads[3].frameCount, 0);
        XCTAssertEqual(output.threads[4].status, SentryThreadCaptureSucceeded);
        XCTAssertTrue(output.threads[4].wasSuspended);
        XCTAssertEqual(output.threads[4].frameCount, SENTRY_THREAD_SNAPSHOT_MAX_FRAMES);
        XCTAssertTrue(output.threads[4].isTruncated);
        // The driver preserves capture order; reversal belongs to model conversion.
        XCTAssertEqual(output.threads[4].addresses[0], 5000);
        XCTAssertEqual(output.threads[4].addresses[SENTRY_THREAD_SNAPSHOT_MAX_FRAMES - 1],
            5000 + SENTRY_THREAD_SNAPSHOT_MAX_FRAMES - 1);
        XCTAssertEqual(strcmp(output.threads[4].name, "worker"), 0);
    }
    sentryThreadSnapshotDestroy(&backend, &output);
    XCTAssertFalse(fixture.unsafeCallback);
}

- (void)testCapture_whenBackendCountInvalidAndNameUnterminated_shouldBoundBothOutputs
{
    // -- Arrange --
    Fixture fixture = { .count = 3, .badCaptureCount = true, .longName = true };
    SentryThreadSnapshotBackend backend = backendFor(&fixture);
    SentryThreadSnapshotBuffer output;

    // -- Act --
    bool success = sentryThreadSnapshotCapture(&backend, true, &output);

    // -- Assert --
    XCTAssertTrue(success);
    XCTAssertEqual(output.count, 3);
    if (output.count == 3) {
        XCTAssertEqual(output.threads[2].status, SentryThreadCaptureUnavailable);
        XCTAssertEqual(output.threads[2].frameCount, 0);
        XCTAssertFalse(output.threads[2].isTruncated);
        XCTAssertEqual(strlen(output.threads[2].name), SENTRY_THREAD_SNAPSHOT_NAME_LENGTH - 1);
    }
    sentryThreadSnapshotDestroy(&backend, &output);
}

@end
