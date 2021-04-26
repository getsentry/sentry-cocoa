#include "SentryHook.h"
#include "fishhook.h"
#include <dispatch/dispatch.h>
#include <execinfo.h>
#include <mach/mach.h>
#include <pthread.h>

void
sentrycrash__async_backtrace_incref(sentrycrash_async_backtrace_t *bt)
{
    if (!bt) {
        return;
    }
    __atomic_fetch_add(&bt->refcount, 1, __ATOMIC_SEQ_CST);
}

void
sentrycrash__async_backtrace_decref(sentrycrash_async_backtrace_t *bt)
{
    if (!bt) {
        return;
    }
    if (__atomic_fetch_add(&bt->refcount, -1, __ATOMIC_SEQ_CST) == 1) {
        sentrycrash__async_backtrace_decref(bt->async_caller);
        free(bt);
    }
}

/**
 * This is a poor-mans concurrent hashtable.
 * We have N slots, using modulo of the thread ID. Using atomic load / compare-exchange to make sure
 * that the slot indeed belongs to the thread we want to work with.
 */

#define SENTRY_MAX_ASYNC_THREADS (128 - 1)

typedef struct {
    SentryCrashThread thread;
    sentrycrash_async_backtrace_t *backtrace;
} sentrycrash_async_caller_t;

static sentrycrash_async_caller_t sentry_async_callers[SENTRY_MAX_ASYNC_THREADS] = { 0 };

static size_t
sentrycrash__thread_idx(SentryCrashThread thread)
{
    // `pthread_t` is an aligned pointer, so lets shift it first then "hash" it.
    return (thread * 19) % SENTRY_MAX_ASYNC_THREADS;
}

sentrycrash_async_backtrace_t *
sentrycrash_get_async_caller_for_thread(SentryCrashThread thread)
{
    size_t idx = sentrycrash__thread_idx(thread);
    sentrycrash_async_caller_t *caller = &sentry_async_callers[idx];
    if (__atomic_load_n(&caller->thread, __ATOMIC_SEQ_CST) == thread) {
        sentrycrash_async_backtrace_t *backtrace = caller->backtrace;
        // we read the thread id *again*, if it is still the same, the backtrace pointer we
        // read in between is valid
        if (__atomic_load_n(&caller->thread, __ATOMIC_SEQ_CST) == thread) {
            return backtrace;
        }
    }
    return NULL;
}

static void
sentrycrash__set_async_caller(sentrycrash_async_backtrace_t *backtrace)
{
    SentryCrashThread thread = sentrycrashthread_self();

    size_t idx = sentrycrash__thread_idx(thread);
    sentrycrash_async_caller_t *caller = &sentry_async_callers[idx];

    SentryCrashThread expected = (SentryCrashThread)NULL;
    bool success = __atomic_compare_exchange_n(
        &caller->thread, &expected, thread, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);

    if (success) {
        __atomic_store_n(&caller->backtrace, backtrace, __ATOMIC_SEQ_CST);
    }
}

static void
sentrycrash__unset_async_caller(sentrycrash_async_backtrace_t *backtrace)
{
    SentryCrashThread thread = sentrycrashthread_self();

    size_t idx = sentrycrash__thread_idx(thread);
    sentrycrash_async_caller_t *caller = &sentry_async_callers[idx];

    __atomic_compare_exchange_n(
        &caller->thread, &thread, (SentryCrashThread)NULL, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);

    sentrycrash__async_backtrace_decref(backtrace);
}

sentrycrash_async_backtrace_t *
sentrycrash__async_backtrace_capture(void)
{
    sentrycrash_async_backtrace_t *bt = malloc(sizeof(sentrycrash_async_backtrace_t));
    bt->refcount = 1;

    bt->len = backtrace(bt->backtrace, MAX_BACKTRACE_FRAMES);

    SentryCrashThread thread = sentrycrashthread_self();
    size_t idx = sentrycrash__thread_idx(thread);
    sentrycrash_async_caller_t *caller = &sentry_async_callers[idx];
    if (__atomic_load_n(&caller->thread, __ATOMIC_SEQ_CST) == thread) {
        sentrycrash__async_backtrace_incref(caller->backtrace);
        bt->async_caller = caller->backtrace;
    } else {
        bt->async_caller = NULL;
    }

    return bt;
}

static bool hooks_active = true;

static void (*real_dispatch_async)(dispatch_queue_t queue, dispatch_block_t block);

void
sentrycrash__hook_dispatch_async(dispatch_queue_t queue, dispatch_block_t block)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_async(queue, block);
    }

    // create a backtrace, capturing the async callsite
    sentrycrash_async_backtrace_t *bt = sentrycrash__async_backtrace_capture();

    return real_dispatch_async(queue, ^{
        // inside the async context, save the backtrace in a thread local for later consumption
        sentrycrash__set_async_caller(bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        sentrycrash__unset_async_caller(bt);
    });
}

static void (*real_dispatch_async_f)(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work);

void
sentrycrash__hook_dispatch_async_f(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_async_f(queue, context, work);
    }
    sentrycrash__hook_dispatch_async(queue, ^{ work(context); });
}

static void (*real_dispatch_after)(
    dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);

void
sentrycrash__hook_dispatch_after(
    dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_after(when, queue, block);
    }

    // create a backtrace, capturing the async callsite
    sentrycrash_async_backtrace_t *bt = sentrycrash__async_backtrace_capture();

    return real_dispatch_after(when, queue, ^{
        // inside the async context, save the backtrace in a thread local for later consumption
        sentrycrash__set_async_caller(bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        sentrycrash__unset_async_caller(bt);
    });
}

static void (*real_dispatch_after_f)(dispatch_time_t when, dispatch_queue_t queue,
    void *_Nullable context, dispatch_function_t work);

void
sentrycrash__hook_dispatch_after_f(
    dispatch_time_t when, dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_after_f(when, queue, context, work);
    }
    sentrycrash__hook_dispatch_after(when, queue, ^{ work(context); });
}

static void (*real_dispatch_barrier_async)(dispatch_queue_t queue, dispatch_block_t block);

void
sentrycrash__hook_dispatch_barrier_async(dispatch_queue_t queue, dispatch_block_t block)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_barrier_async(queue, block);
    }

    // create a backtrace, capturing the async callsite
    sentrycrash_async_backtrace_t *bt = sentrycrash__async_backtrace_capture();

    return real_dispatch_barrier_async(queue, ^{
        // inside the async context, save the backtrace in a thread local for later consumption
        sentrycrash__set_async_caller(bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        sentrycrash__unset_async_caller(bt);
    });
}

static void (*real_dispatch_barrier_async_f)(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work);

void
sentrycrash__hook_dispatch_barrier_async_f(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_barrier_async_f(queue, context, work);
    }
    sentrycrash__hook_dispatch_barrier_async(queue, ^{ work(context); });
}

static bool hooks_installed = false;

void
sentrycrash_install_async_hooks(void)
{
    __atomic_store_n(&hooks_active, true, __ATOMIC_RELAXED);

    if (__atomic_exchange_n(&hooks_installed, true, __ATOMIC_SEQ_CST)) {
        return;
    }

    sentrycrash__hook_rebind_symbols(
        (struct rebinding[6]) {
            { "dispatch_async", sentrycrash__hook_dispatch_async, (void *)&real_dispatch_async },
            { "dispatch_async_f", sentrycrash__hook_dispatch_async_f,
                (void *)&real_dispatch_async_f },
            { "dispatch_after", sentrycrash__hook_dispatch_after, (void *)&real_dispatch_after },
            { "dispatch_after_f", sentrycrash__hook_dispatch_after_f,
                (void *)&real_dispatch_after_f },
            { "dispatch_barrier_async", sentrycrash__hook_dispatch_barrier_async,
                (void *)&real_dispatch_barrier_async },
            { "dispatch_barrier_async_f", sentrycrash__hook_dispatch_barrier_async_f,
                (void *)&real_dispatch_barrier_async_f },
        },
        6);

    // NOTE: We will *not* hook the following functions:
    //
    // - dispatch_async_and_wait
    // - dispatch_async_and_wait_f
    // - dispatch_barrier_async_and_wait
    // - dispatch_barrier_async_and_wait_f
    //
    // Because these functions `will use the stack of the submitting thread` in some cases
    // and our thread tracking logic would do the wrong thing in that case.
    //
    // See:
    // https://github.com/apple/swift-corelibs-libdispatch/blob/f13ea5dcc055e5d2d7c02e90d8c9907ca9dc72e1/private/workloop_private.h#L321-L326
}

void
sentrycrash_deactivate_async_hooks()
{
    // Instead of reverting the rebinding (which is not really possible), we rather
    // deactivate the hooks. They still exist, and still get called, but they will just
    // call through to the real libdispatch functions immediately.
    __atomic_store_n(&hooks_active, false, __ATOMIC_RELAXED);
}
