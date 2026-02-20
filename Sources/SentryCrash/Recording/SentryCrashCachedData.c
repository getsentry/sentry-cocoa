// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashCachedData.c
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "SentryCrashCachedData.h"

#include "SentryAsyncSafeLog.h"

#include <errno.h>
#include <mach/mach.h>
#include <memory.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// MARK: - Types

typedef struct {
    SentryCrashThread *machThreads;
    SentryCrashThread *pthreads;
    const char **threadNames;
    int count;
} SentryCrashThreadCacheData;

// MARK: - Globals

static atomic_int g_pollingIntervalInSeconds;
static pthread_t g_cacheThread;
static atomic_bool g_hasThreadStarted;
static atomic_bool g_isThreadStopping;
static atomic_int g_quickPollCount;

/** True once a cache has been successfully created. Used by updateCache()
 *  to distinguish g_activeCache == NULL meaning "frozen" vs "never created".
 */
static atomic_bool g_cacheEverCreated;

/** The active cache, continuously updated by the background thread.
 *  NULL when the crash handler has acquired ownership via freeze(),
 *  or when no cache has been successfully created yet (distinguished
 *  by g_cacheEverCreated).
 */
static _Atomic(SentryCrashThreadCacheData *) g_activeCache;

/** Cache snapshot acquired by sentrycrashccd_freeze(). Reader functions
 *  (getThreadName, getQueueName) read from this pointer so they always
 *  see a consistent, fully-constructed snapshot that cannot be freed
 *  while they are using it.
 */
static _Atomic(SentryCrashThreadCacheData *) g_frozenCache;

// MARK: - Private Helpers

static void
freeCache(SentryCrashThreadCacheData *cache)
{
    if (cache == NULL) {
        return;
    }

    if (cache->threadNames != NULL) {
        for (int i = 0; i < cache->count; i++) {
            if (cache->threadNames[i] != NULL) {
                free((void *)cache->threadNames[i]);
            }
        }
        free(cache->threadNames);
    }

    if (cache->machThreads != NULL) {
        free(cache->machThreads);
    }

    if (cache->pthreads != NULL) {
        free(cache->pthreads);
    }

    free(cache);
}

static SentryCrashThreadCacheData *
createCache(void)
{
    const task_t thisTask = mach_task_self();
    mach_msg_type_number_t threadCount;
    thread_act_array_t threads;
    kern_return_t kr;

    if ((kr = task_threads(thisTask, &threads, &threadCount)) != KERN_SUCCESS) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("task_threads: %s", mach_error_string(kr));
        return NULL;
    }

    SentryCrashThreadCacheData *cache = calloc(1, sizeof(*cache));
    if (cache == NULL) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Failed to allocate thread cache");
        goto cleanup_threads;
    }

    cache->count = (int)threadCount;
    cache->machThreads = calloc(threadCount, sizeof(*cache->machThreads));
    cache->pthreads = calloc(threadCount, sizeof(*cache->pthreads));
    cache->threadNames = calloc(threadCount, sizeof(*cache->threadNames));

    if (cache->machThreads == NULL || cache->pthreads == NULL || cache->threadNames == NULL) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Failed to allocate thread cache arrays");
        freeCache(cache);
        cache = NULL;
        goto cleanup_threads;
    }

    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        char buffer[1000];
        thread_t thread = threads[i];
        pthread_t pthread = pthread_from_mach_thread_np(thread);

        cache->machThreads[i] = (SentryCrashThread)thread;
        cache->pthreads[i] = (SentryCrashThread)pthread;

        if (pthread != 0 && pthread_getname_np(pthread, buffer, sizeof(buffer)) == 0
            && buffer[0] != 0) {
            cache->threadNames[i] = strdup(buffer);
        }
    }

cleanup_threads:
    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * threadCount);

    return cache;
}

/** Atomically replace the active cache with a freshly created snapshot.
 *  If the cache is currently frozen (acquired by the crash handler), this
 *  update is skipped entirely — the crash handler owns the pointer and we
 *  must not interfere.
 */
static void
updateCache(void)
{
    // Build new cache first so g_activeCache keeps the old (valid) pointer
    // during construction. If a crash occurs mid-build, freeze() will
    // still find usable data instead of NULL.
    SentryCrashThreadCacheData *newCache = createCache();
    if (newCache == NULL) {
        // Creation failed; keep the old cache so readers still work.
        return;
    }

    // Install new cache via compare-and-swap.
    SentryCrashThreadCacheData *expected = atomic_load(&g_activeCache);
    if (expected == NULL) {
        // Disambiguate NULL g_activeCache using g_cacheEverCreated.
        if (atomic_load(&g_cacheEverCreated)) {
            // Case 1: Frozen by crash handler, skip this update cycle.
            freeCache(newCache);
            return;
        }
        // Case 2: No cache exists yet. Try to install the new one.
        if (atomic_compare_exchange_strong(&g_activeCache, &expected, newCache)) {
            // Case 2a: Successfully installed new cache.
            atomic_store(&g_cacheEverCreated, true);
        } else {
            // Case 2b: Another thread installed a cache concurrently. Discard ours.
            freeCache(newCache);
        }
        return;
    }

    if (atomic_compare_exchange_strong(&g_activeCache, &expected, newCache)) {
        // Case A: Successfully swapped old cache for new one.
        atomic_store(&g_cacheEverCreated, true);
        freeCache(expected);
    } else {
        // Case B: Cache was acquired by freeze() between our load and CAS.
        freeCache(newCache);
    }
}

static void *
monitorThreadCache(__unused void *const userData)
{
    usleep(1);
    while (!atomic_load(&g_isThreadStopping)) {
        updateCache();
        unsigned pollInterval = (unsigned)atomic_load(&g_pollingIntervalInSeconds);
        int remainingQuickPolls = atomic_load(&g_quickPollCount);
        if (remainingQuickPolls > 0) {
            // Lots can happen in the first few seconds of operation.
            atomic_store(&g_quickPollCount, remainingQuickPolls - 1);
            pollInterval = 1;
        }
        for (unsigned i = 0; i < pollInterval && !atomic_load(&g_isThreadStopping); i++) {
            sleep(1);
        }
    }
    return NULL;
}

// MARK: - Public API

void
sentrycrashccd_init(int pollingIntervalInSeconds)
{
    if (atomic_exchange(&g_hasThreadStarted, true)) {
        return;
    }

    atomic_store(&g_pollingIntervalInSeconds, pollingIntervalInSeconds);
    atomic_store(&g_frozenCache, NULL);
    atomic_store(&g_cacheEverCreated, false);
    atomic_store(&g_isThreadStopping, false);
    atomic_store(&g_quickPollCount, 4);

    // Create initial cache
    SentryCrashThreadCacheData *initialCache = createCache();
    atomic_store(&g_activeCache, initialCache);
    if (initialCache != NULL) {
        atomic_store(&g_cacheEverCreated, true);
    }

    // Start background monitoring thread.
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
    int error = pthread_create(
        &g_cacheThread, &attr, &monitorThreadCache, "SentryCrash Cached Data Monitor");
    if (error != 0) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("pthread_create: %s", SENTRY_STRERROR_R(error));
    }
    pthread_attr_destroy(&attr);
}

void
sentrycrashccd_freeze(void)
{
    // Atomically take ownership of the cache so the background thread
    // cannot free it while the crash handler reads from it.
    SentryCrashThreadCacheData *cache = atomic_exchange(&g_activeCache, NULL);

    // Only update g_frozenCache if we actually acquired a cache.
    // A nested freeze (recrash scenario) gets NULL from g_activeCache;
    // we must not overwrite the still-valid frozen pointer from the first freeze.
    if (cache != NULL) {
        atomic_store(&g_frozenCache, cache);
    }
}

void
sentrycrashccd_unfreeze(void)
{
    SentryCrashThreadCacheData *cache = atomic_exchange(&g_frozenCache, NULL);
    if (cache != NULL) {
        SentryCrashThreadCacheData *expected = NULL;
        if (!atomic_compare_exchange_strong(&g_activeCache, &expected, cache)) {
            // updateCache() already installed a fresh cache; discard the stale one.
            freeCache(cache);
        }
    }
}

const char *
sentrycrashccd_getThreadName(SentryCrashThread thread)
{
    SentryCrashThreadCacheData *cache = atomic_load(&g_frozenCache);
    if (cache == NULL || cache->machThreads == NULL || cache->threadNames == NULL) {
        return NULL;
    }

    for (int i = 0; i < cache->count; i++) {
        if (cache->machThreads[i] == thread) {
            return cache->threadNames[i];
        }
    }
    return NULL;
}

const char *
sentrycrashccd_getQueueName(__unused SentryCrashThread thread)
{
    // Queue name caching is not yet implemented in our fork.
    // KSCrash upstream populates queue names via ksthread_getQueueName()
    // (in KSThread.c) which uses thread_info() with THREAD_IDENTIFIER_INFO
    // to resolve dispatch_queue_t and then dispatch_queue_get_label().
    // See: https://github.com/kstenerud/KSCrash/blob/master/Sources/KSCrashRecordingCore/KSThread.c
    return NULL;
}

void
sentrycrashccd_close(void)
{
    if (atomic_exchange(&g_hasThreadStarted, false)) {
        // Signal the thread to exit and wait for it to finish.
        atomic_store(&g_isThreadStopping, true);
        pthread_join(g_cacheThread, NULL);

        // Free both caches. freeze() atomically moves the pointer from
        // g_activeCache to g_frozenCache, so they never alias each other.
        SentryCrashThreadCacheData *active = atomic_exchange(&g_activeCache, NULL);
        freeCache(active);

        SentryCrashThreadCacheData *frozen = atomic_exchange(&g_frozenCache, NULL);
        freeCache(frozen);

        atomic_store(&g_cacheEverCreated, false);
    }
}

bool
sentrycrashccd_hasThreadStarted(void)
{
    return atomic_load(&g_hasThreadStarted);
}

// MARK: - Testing

void
sentrycrashccd_test_clearActiveCache(void)
{
    SentryCrashThreadCacheData *cache = atomic_exchange(&g_activeCache, NULL);
    freeCache(cache);
    // Reset so updateCache() sees "never created" instead of "frozen".
    atomic_store(&g_cacheEverCreated, false);
}
