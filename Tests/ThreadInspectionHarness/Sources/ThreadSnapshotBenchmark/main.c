#include <KSDynamicLinker.h>
#include <SentryThreadSnapshot.h>
#include <errno.h>
#include <limits.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>
#include <time.h>

#define MAX_AXIS_VALUES 32

typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t condition;
    size_t ready;
    bool stop;
    int stackDepth;
} WorkerPool;

typedef struct {
    SentryThreadSnapshotBackend delegate;
    size_t suspendAttempts;
    size_t successfulSuspensions;
    size_t captureCalls;
    size_t resumeCalls;
    uint64_t firstSuspendCallBegin;
    uint64_t firstSuspensionComplete;
    uint64_t allSuspendedBegin;
    uint64_t firstUnwindBegin;
    uint64_t firstResumeBegin;
    uint64_t firstResumeEnd;
    uint64_t lastResumeEnd;
} TimedBackendContext;

typedef struct {
    double suspendPhaseMs;
    double allSuspendedMs;
    double firstTargetPauseMs;
    double resumePhaseMs;
    double suspendResumeMs;
    double stopWindowMs;
    double totalCaptureMs;
    size_t enumerated;
    size_t suspended;
    size_t captured;
    size_t frames;
    size_t truncated;
} Sample;

typedef enum {
    MetricSuspendPhase,
    MetricAllSuspended,
    MetricFirstTargetPause,
    MetricResumePhase,
    MetricSuspendResume,
    MetricStopWindow,
    MetricTotalCapture,
} Metric;

static mach_timebase_info_data_t timebase;

__attribute__((noinline)) static int
waitAtDepth(WorkerPool *pool, int depth)
{
    if (depth > 0) {
        // Keep every recursive frame live in optimized benchmark builds.
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
    pthread_setname_np("snapshot-bench");
    waitAtDepth(pool, pool->stackDepth);
    return NULL;
}

static bool
startWorkers(WorkerPool *pool, pthread_t *workers, size_t count)
{
    size_t created = 0;
    for (; created < count; created++) {
        int result = pthread_create(&workers[created], NULL, workerMain, pool);
        if (result != 0) {
            fprintf(
                stderr, "pthread_create failed after %zu workers: %s\n", created, strerror(result));
            break;
        }
    }

    pthread_mutex_lock(&pool->mutex);
    while (pool->ready < created) {
        pthread_cond_wait(&pool->condition, &pool->mutex);
    }
    pthread_mutex_unlock(&pool->mutex);

    if (created == count) {
        return true;
    }

    pthread_mutex_lock(&pool->mutex);
    pool->stop = true;
    pthread_cond_broadcast(&pool->condition);
    pthread_mutex_unlock(&pool->mutex);
    for (size_t i = 0; i < created; i++) {
        pthread_join(workers[i], NULL);
    }
    return false;
}

static void
stopWorkers(WorkerPool *pool, pthread_t *workers, size_t count)
{
    pthread_mutex_lock(&pool->mutex);
    pool->stop = true;
    pthread_cond_broadcast(&pool->condition);
    pthread_mutex_unlock(&pool->mutex);
    for (size_t i = 0; i < count; i++) {
        pthread_join(workers[i], NULL);
    }
}

static double
milliseconds(uint64_t begin, uint64_t end)
{
    long double nanoseconds
        = (long double)(end - begin) * (long double)timebase.numer / (long double)timebase.denom;
    return (double)(nanoseconds / 1000000.0L);
}

static bool
timedEnumerate(void *context, void **list, size_t *count)
{
    TimedBackendContext *timed = context;
    return timed->delegate.enumerate(timed->delegate.context, list, count);
}

static void
timedReleaseList(void *context, void *list, size_t count)
{
    TimedBackendContext *timed = context;
    timed->delegate.releaseList(timed->delegate.context, list, count);
}

static uintptr_t
timedThreadAt(void *context, void *list, size_t index)
{
    TimedBackendContext *timed = context;
    return timed->delegate.threadAt(timed->delegate.context, list, index);
}

static uintptr_t
timedCurrentThread(void *context)
{
    TimedBackendContext *timed = context;
    return timed->delegate.currentThread(timed->delegate.context);
}

static uintptr_t
timedMainThread(void *context)
{
    TimedBackendContext *timed = context;
    return timed->delegate.mainThread(timed->delegate.context);
}

static bool
timedCanCapture(void *context)
{
    TimedBackendContext *timed = context;
    return timed->delegate.canCapture(timed->delegate.context);
}

static bool
timedIsReserved(void *context, uintptr_t thread)
{
    TimedBackendContext *timed = context;
    return timed->delegate.isReserved(timed->delegate.context, thread);
}

static bool
timedSuspend(void *context, uintptr_t thread)
{
    TimedBackendContext *timed = context;
    uint64_t candidateCallBegin = timed->successfulSuspensions == 0 ? mach_absolute_time() : 0;
    timed->suspendAttempts++;
    bool succeeded = timed->delegate.suspend(timed->delegate.context, thread);
    if (succeeded) {
        uint64_t suspensionCompleted = mach_absolute_time();
        if (timed->successfulSuspensions == 0) {
            timed->firstSuspendCallBegin = candidateCallBegin;
            // Pause metrics start at the first point where a target is known to be stopped.
            timed->firstSuspensionComplete = suspensionCompleted;
        }
        // Keep the latest successful completion. Failed attempts after it are correctly included
        // because every already-acquired target remains stopped until the resume phase.
        timed->allSuspendedBegin = suspensionCompleted;
        timed->successfulSuspensions++;
    }
    return succeeded;
}

static size_t
timedCaptureSuspended(
    void *context, uintptr_t thread, uintptr_t *addresses, size_t capacity, bool *isTruncated)
{
    TimedBackendContext *timed = context;
    if (timed->captureCalls == 0) {
        // Every suspend attempt and all suspension-loop bookkeeping have completed.
        timed->firstUnwindBegin = mach_absolute_time();
    }
    timed->captureCalls++;
    return timed->delegate.captureSuspended(
        timed->delegate.context, thread, addresses, capacity, isTruncated);
}

static void
timedResume(void *context, uintptr_t thread)
{
    TimedBackendContext *timed = context;
    bool isFirst = timed->resumeCalls == 0;
    bool isLast = timed->resumeCalls + 1 == timed->successfulSuspensions;
    if (isFirst) {
        timed->firstResumeBegin = mach_absolute_time();
    }
    timed->delegate.resume(timed->delegate.context, thread);
    timed->resumeCalls++;
    if (isFirst || isLast) {
        uint64_t end = mach_absolute_time();
        if (isFirst) {
            timed->firstResumeEnd = end;
        }
        if (isLast) {
            timed->lastResumeEnd = end;
        }
    }
}

static bool
timedName(void *context, uintptr_t thread, char *buffer, size_t capacity)
{
    TimedBackendContext *timed = context;
    return timed->delegate.name(timed->delegate.context, thread, buffer, capacity);
}

static void *
timedAllocate(void *context, size_t count, size_t size)
{
    TimedBackendContext *timed = context;
    return timed->delegate.allocate(timed->delegate.context, count, size);
}

static void
timedDeallocate(void *context, void *allocation)
{
    TimedBackendContext *timed = context;
    timed->delegate.deallocate(timed->delegate.context, allocation);
}

static SentryThreadSnapshotBackend
timedBackend(TimedBackendContext *context)
{
    return (SentryThreadSnapshotBackend) {
        .context = context,
        .enumerate = timedEnumerate,
        .releaseList = timedReleaseList,
        .threadAt = timedThreadAt,
        .currentThread = timedCurrentThread,
        .mainThread = timedMainThread,
        .canCapture = context->delegate.canCapture == NULL ? NULL : timedCanCapture,
        .isReserved = timedIsReserved,
        .suspend = timedSuspend,
        .captureSuspended = timedCaptureSuspended,
        .resume = timedResume,
        .name = timedName,
        .allocate = timedAllocate,
        .deallocate = timedDeallocate,
    };
}

static void
resetTiming(TimedBackendContext *context)
{
    context->suspendAttempts = 0;
    context->successfulSuspensions = 0;
    context->captureCalls = 0;
    context->resumeCalls = 0;
    context->firstSuspendCallBegin = 0;
    context->firstSuspensionComplete = 0;
    context->allSuspendedBegin = 0;
    context->firstUnwindBegin = 0;
    context->firstResumeBegin = 0;
    context->firstResumeEnd = 0;
    context->lastResumeEnd = 0;
}

static bool
captureSample(SentryThreadSnapshotBackend *backend, TimedBackendContext *timed, pthread_t *workers,
    size_t workerCount, Sample *sample)
{
    resetTiming(timed);
    SentryThreadSnapshotBuffer output;
    uint64_t totalBegin = mach_absolute_time();
    bool succeeded = sentryThreadSnapshotCapture(backend, true, &output);
    uint64_t totalEnd = mach_absolute_time();
    if (!succeeded) {
        fprintf(stderr, "snapshot capture failed\n");
        return false;
    }

    bool valid = timed->successfulSuspensions >= workerCount
        && timed->captureCalls == timed->successfulSuspensions
        && timed->resumeCalls == timed->successfulSuspensions && timed->firstSuspendCallBegin != 0
        && timed->firstSuspensionComplete != 0 && timed->allSuspendedBegin != 0
        && timed->firstUnwindBegin != 0 && timed->firstResumeBegin != 0
        && timed->firstResumeEnd != 0 && timed->lastResumeEnd != 0
        && timed->firstSuspendCallBegin < timed->firstSuspensionComplete
        && timed->firstSuspensionComplete <= timed->allSuspendedBegin
        && timed->allSuspendedBegin <= timed->firstUnwindBegin
        && timed->firstUnwindBegin <= timed->firstResumeBegin
        && timed->firstResumeBegin <= timed->firstResumeEnd
        && timed->firstResumeEnd <= timed->lastResumeEnd;

    size_t captured = 0;
    size_t frames = 0;
    size_t truncated = 0;
    for (size_t i = 0; i < output.count; i++) {
        const SentryThreadSnapshot *thread = &output.threads[i];
        if (thread->status == SentryThreadCaptureSucceeded) {
            captured++;
            frames += thread->frameCount;
            truncated += thread->isTruncated ? 1 : 0;
        }
    }
    for (size_t i = 0; i < workerCount; i++) {
        uintptr_t identity = pthread_mach_thread_np(workers[i]);
        bool found = false;
        for (size_t j = 0; j < output.count; j++) {
            if (output.threads[j].thread == identity) {
                found = output.threads[j].status == SentryThreadCaptureSucceeded;
                break;
            }
        }
        if (!found) {
            fprintf(stderr, "worker %zu was not captured successfully\n", i);
            valid = false;
        }
    }

    if (!valid) {
        fprintf(stderr,
            "invalid capture: enumerated=%zu attempts=%zu suspended=%zu unwound=%zu resumed=%zu\n",
            output.count, timed->suspendAttempts, timed->successfulSuspensions, timed->captureCalls,
            timed->resumeCalls);
        sentryThreadSnapshotDestroy(backend, &output);
        return false;
    }

    if (sample != NULL) {
        double suspendPhaseMs = milliseconds(timed->firstSuspendCallBegin, timed->firstUnwindBegin);
        double resumePhaseMs = milliseconds(timed->firstResumeBegin, timed->lastResumeEnd);
        *sample = (Sample) {
            .suspendPhaseMs = suspendPhaseMs,
            .allSuspendedMs = milliseconds(timed->allSuspendedBegin, timed->firstResumeBegin),
            .firstTargetPauseMs
            = milliseconds(timed->firstSuspensionComplete, timed->firstResumeEnd),
            .resumePhaseMs = resumePhaseMs,
            .suspendResumeMs = suspendPhaseMs + resumePhaseMs,
            .stopWindowMs = milliseconds(timed->firstSuspensionComplete, timed->lastResumeEnd),
            .totalCaptureMs = milliseconds(totalBegin, totalEnd),
            .enumerated = output.count,
            .suspended = timed->successfulSuspensions,
            .captured = captured,
            .frames = frames,
            .truncated = truncated,
        };
    }
    sentryThreadSnapshotDestroy(backend, &output);
    return true;
}

static double
metricValue(const Sample *sample, Metric metric)
{
    switch (metric) {
    case MetricSuspendPhase:
        return sample->suspendPhaseMs;
    case MetricAllSuspended:
        return sample->allSuspendedMs;
    case MetricFirstTargetPause:
        return sample->firstTargetPauseMs;
    case MetricResumePhase:
        return sample->resumePhaseMs;
    case MetricSuspendResume:
        return sample->suspendResumeMs;
    case MetricStopWindow:
        return sample->stopWindowMs;
    case MetricTotalCapture:
        return sample->totalCaptureMs;
    }
    return 0;
}

static int
compareDouble(const void *left, const void *right)
{
    double lhs = *(const double *)left;
    double rhs = *(const double *)right;
    return (lhs > rhs) - (lhs < rhs);
}

static double
percentile(const Sample *samples, size_t count, Metric metric, size_t percentage, double *scratch)
{
    for (size_t i = 0; i < count; i++) {
        scratch[i] = metricValue(&samples[i], metric);
    }
    qsort(scratch, count, sizeof(*scratch), compareDouble);
    // Nearest-rank percentile without overflowing percentage * count.
    size_t rank = (count / 100) * percentage + ((count % 100) * percentage + 99) / 100;
    return scratch[rank - 1];
}

static void
printScenario(
    size_t workerCount, int stackDepth, const Sample *samples, size_t sampleCount, double *scratch)
{
    size_t enumeratedMin = SIZE_MAX;
    size_t enumeratedMax = 0;
    size_t suspendedMin = SIZE_MAX;
    size_t suspendedMax = 0;
    size_t capturedTotal = 0;
    size_t framesTotal = 0;
    size_t truncatedTotal = 0;
    for (size_t i = 0; i < sampleCount; i++) {
        enumeratedMin
            = samples[i].enumerated < enumeratedMin ? samples[i].enumerated : enumeratedMin;
        enumeratedMax
            = samples[i].enumerated > enumeratedMax ? samples[i].enumerated : enumeratedMax;
        suspendedMin = samples[i].suspended < suspendedMin ? samples[i].suspended : suspendedMin;
        suspendedMax = samples[i].suspended > suspendedMax ? samples[i].suspended : suspendedMax;
        capturedTotal += samples[i].captured;
        framesTotal += samples[i].frames;
        truncatedTotal += samples[i].truncated;
    }
    double meanFrames = capturedTotal == 0 ? 0 : (double)framesTotal / (double)capturedTotal;

    printf("%zu,%d,%zu,%zu,%zu,%zu,%zu,%.1f,%zu,", workerCount, stackDepth, sampleCount,
        enumeratedMin, enumeratedMax, suspendedMin, suspendedMax, meanFrames, truncatedTotal);
    for (Metric metric = MetricSuspendPhase; metric <= MetricTotalCapture; metric++) {
        printf("%.6f,%.6f%s", percentile(samples, sampleCount, metric, 50, scratch),
            percentile(samples, sampleCount, metric, 95, scratch),
            metric == MetricTotalCapture ? "\n" : ",");
    }
    fflush(stdout);
}

static bool
runScenario(size_t workerCount, int stackDepth, size_t warmupCount, size_t sampleCount,
    Sample *samples, double *scratch, bool printResults)
{
    WorkerPool pool;
    if (pthread_mutex_init(&pool.mutex, NULL) != 0) {
        fprintf(stderr, "worker mutex initialization failed\n");
        return false;
    }
    if (pthread_cond_init(&pool.condition, NULL) != 0) {
        fprintf(stderr, "worker condition initialization failed\n");
        pthread_mutex_destroy(&pool.mutex);
        return false;
    }
    pool.ready = 0;
    pool.stop = false;
    pool.stackDepth = stackDepth;

    pthread_t *workers = calloc(workerCount, sizeof(*workers));
    if (workers == NULL) {
        fprintf(stderr, "could not allocate %zu worker handles\n", workerCount);
        pthread_cond_destroy(&pool.condition);
        pthread_mutex_destroy(&pool.mutex);
        return false;
    }
    if (!startWorkers(&pool, workers, workerCount)) {
        free(workers);
        pthread_cond_destroy(&pool.condition);
        pthread_mutex_destroy(&pool.mutex);
        return false;
    }

    TimedBackendContext timed = { .delegate = sentryThreadSnapshotKSCrashBackend() };
    SentryThreadSnapshotBackend backend = timedBackend(&timed);
    bool succeeded = true;
    for (size_t i = 0; i < warmupCount; i++) {
        if (!captureSample(&backend, &timed, workers, workerCount, NULL)) {
            succeeded = false;
            break;
        }
    }
    for (size_t i = 0; succeeded && i < sampleCount; i++) {
        if (!captureSample(&backend, &timed, workers, workerCount, &samples[i])) {
            succeeded = false;
        }
    }

    if (succeeded && printResults) {
        printScenario(workerCount, stackDepth, samples, sampleCount, scratch);
    }
    stopWorkers(&pool, workers, workerCount);
    free(workers);
    pthread_cond_destroy(&pool.condition);
    pthread_mutex_destroy(&pool.mutex);
    return succeeded;
}

static bool
parseUnsigned(const char *text, size_t *value)
{
    if (text[0] == '\0' || text[0] == '-') {
        return false;
    }
    errno = 0;
    char *end = NULL;
    unsigned long long parsed = strtoull(text, &end, 10);
    if (errno != 0 || *end != '\0' || parsed > SIZE_MAX) {
        return false;
    }
    *value = (size_t)parsed;
    return true;
}

static bool
parseList(const char *text, size_t *values, size_t *count)
{
    *count = 0;
    const char *cursor = text;
    while (*cursor != '\0') {
        if (*count == MAX_AXIS_VALUES || *cursor == '-' || *cursor == ',') {
            return false;
        }
        errno = 0;
        char *end = NULL;
        unsigned long long parsed = strtoull(cursor, &end, 10);
        if (errno != 0 || end == cursor || parsed > SIZE_MAX) {
            return false;
        }
        values[(*count)++] = (size_t)parsed;
        if (*end == '\0') {
            return true;
        }
        if (*end != ',') {
            return false;
        }
        cursor = end + 1;
    }
    return false;
}

static void
printUsage(const char *program)
{
    fprintf(stderr,
        "Usage: %s [--workers 1,16,64,128] [--depths 0,64,256,512] "
        "[--warmups 5] [--iterations 30]\n",
        program);
}

static void
sysctlString(const char *name, char *buffer, size_t capacity)
{
    size_t size = capacity;
    if (sysctlbyname(name, buffer, &size, NULL, 0) != 0 || size == 0) {
        snprintf(buffer, capacity, "unknown");
    }
    buffer[capacity - 1] = '\0';
}

static void
printEnvironment(size_t warmups, size_t iterations, size_t primingWorkers, size_t primingDepth)
{
    struct utsname system = { 0 };
    uname(&system);
    char productVersion[64];
    char buildVersion[64];
    char hardwareModel[128];
    char cpu[128];
    char timestamp[32] = "unknown";
    time_t wallTime = time(NULL);
    struct tm utcTime;
    if (wallTime != (time_t)-1 && gmtime_r(&wallTime, &utcTime) != NULL) {
        strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", &utcTime);
    }
    sysctlString("kern.osproductversion", productVersion, sizeof(productVersion));
    sysctlString("kern.osversion", buildVersion, sizeof(buildVersion));
    sysctlString("hw.model", hardwareModel, sizeof(hardwareModel));
    sysctlString("machdep.cpu.brand_string", cpu, sizeof(cpu));
#ifdef __OPTIMIZE__
    const char *optimization = "optimized";
#else
    const char *optimization = "unoptimized";
#endif
    printf("# ThreadSnapshotBenchmark schema=1 timestamp=%s\n", timestamp);
    printf("# os=macOS %s (%s) kernel=%s architecture=%s\n", productVersion, buildVersion,
        system.release, system.machine);
    printf("# hardware_model=%s cpu=%s optimization=%s\n", hardwareModel, cpu, optimization);
    printf("# priming_captures=%zu priming_workers=%zu priming_depth=%zu "
           "per_scenario_warmups=%zu iterations=%zu percentile=nearest-rank "
           "clock=mach_absolute_time\n",
        warmups, primingWorkers, primingDepth, warmups, iterations);
    printf("workers,stack_depth,iterations,enumerated_min,enumerated_max,suspended_min,"
           "suspended_max,mean_frames_per_stack,truncated_stack_total,suspend_phase_p50_ms,"
           "suspend_phase_p95_ms,all_suspended_p50_ms,all_suspended_p95_ms,"
           "first_target_pause_p50_ms,first_target_pause_p95_ms,resume_phase_p50_ms,"
           "resume_phase_p95_ms,suspend_resume_p50_ms,suspend_resume_p95_ms,"
           "stop_window_p50_ms,stop_window_p95_ms,total_capture_p50_ms,"
           "total_capture_p95_ms\n");
    fflush(stdout);
}

int
main(int argc, const char **argv)
{
    size_t workerCounts[MAX_AXIS_VALUES] = { 1, 16, 64, 128 };
    size_t workerCountValues = 4;
    size_t stackDepths[MAX_AXIS_VALUES] = { 0, 64, 256, 512 };
    size_t stackDepthValues = 4;
    size_t warmups = 5;
    size_t iterations = 30;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            printUsage(argv[0]);
            return EXIT_SUCCESS;
        }
        if (i + 1 >= argc) {
            printUsage(argv[0]);
            return EXIT_FAILURE;
        }
        const char *value = argv[++i];
        if (strcmp(argv[i - 1], "--workers") == 0) {
            if (!parseList(value, workerCounts, &workerCountValues)) {
                fprintf(stderr, "invalid worker list: %s\n", value);
                return EXIT_FAILURE;
            }
        } else if (strcmp(argv[i - 1], "--depths") == 0) {
            if (!parseList(value, stackDepths, &stackDepthValues)) {
                fprintf(stderr, "invalid stack-depth list: %s\n", value);
                return EXIT_FAILURE;
            }
            for (size_t j = 0; j < stackDepthValues; j++) {
                if (stackDepths[j] > INT_MAX) {
                    fprintf(stderr, "stack depth is too large: %zu\n", stackDepths[j]);
                    return EXIT_FAILURE;
                }
            }
        } else if (strcmp(argv[i - 1], "--warmups") == 0) {
            if (!parseUnsigned(value, &warmups)) {
                fprintf(stderr, "invalid warmup count: %s\n", value);
                return EXIT_FAILURE;
            }
        } else if (strcmp(argv[i - 1], "--iterations") == 0) {
            if (!parseUnsigned(value, &iterations) || iterations == 0) {
                fprintf(stderr, "invalid iteration count: %s\n", value);
                return EXIT_FAILURE;
            }
        } else {
            fprintf(stderr, "unknown option: %s\n", argv[i - 1]);
            printUsage(argv[0]);
            return EXIT_FAILURE;
        }
    }
    for (size_t i = 0; i < workerCountValues; i++) {
        if (workerCounts[i] == 0) {
            fprintf(stderr, "worker counts must be greater than zero\n");
            return EXIT_FAILURE;
        }
    }

    if (mach_timebase_info(&timebase) != KERN_SUCCESS) {
        fprintf(stderr, "mach_timebase_info failed\n");
        return EXIT_FAILURE;
    }
    // Match SDK startup: initialize the preallocated binary-image cache before any suspension.
    ksdl_init();

    Sample *samples = calloc(iterations, sizeof(*samples));
    double *scratch = calloc(iterations, sizeof(*scratch));
    if (samples == NULL || scratch == NULL) {
        fprintf(stderr, "could not allocate benchmark samples\n");
        free(samples);
        free(scratch);
        return EXIT_FAILURE;
    }

    size_t primingWorkers = workerCounts[0];
    size_t primingDepth = stackDepths[0];
    for (size_t i = 1; i < workerCountValues; i++) {
        primingWorkers = workerCounts[i] > primingWorkers ? workerCounts[i] : primingWorkers;
    }
    for (size_t i = 1; i < stackDepthValues; i++) {
        primingDepth = stackDepths[i] > primingDepth ? stackDepths[i] : primingDepth;
    }

    // Prime CPU frequency and unwind caches with the largest requested scenario so the first row
    // does not carry a systematic cold-start bias. The regular warmups still run per scenario.
    bool succeeded = warmups == 0
        || runScenario(primingWorkers, (int)primingDepth, warmups, 0, samples, scratch, false);
    printEnvironment(warmups, iterations, primingWorkers, primingDepth);
    for (size_t depthIndex = 0; succeeded && depthIndex < stackDepthValues; depthIndex++) {
        for (size_t workerIndex = 0; succeeded && workerIndex < workerCountValues; workerIndex++) {
            succeeded = runScenario(workerCounts[workerIndex], (int)stackDepths[depthIndex],
                warmups, iterations, samples, scratch, true);
        }
    }

    free(samples);
    free(scratch);
    return succeeded ? EXIT_SUCCESS : EXIT_FAILURE;
}
