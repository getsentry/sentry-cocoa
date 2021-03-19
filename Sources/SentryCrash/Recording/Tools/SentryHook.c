#include "SentryHook.h"
#include "fishhook.h"
#include <dispatch/dispatch.h>
#include <execinfo.h>
#include <pthread.h>

/**
 * This is a poor-mans concurrent hashtable.
 * We have N slots, using modulo of the thread ID. Using atomic load / compare-exchange to make sure
 * that the slot indeed belongs to the thread we want to work with.
 */

#define SENTRY_MAX_ASYNC_THREADS 64

typedef struct {
    SentryCrashThread thread;
    sentry_async_backtrace_t *backtrace;
} sentry_async_caller_t;

static sentry_async_caller_t sentry_async_callers[SENTRY_MAX_ASYNC_THREADS] = { 0 };

sentry_async_backtrace_t *
sentry_get_async_caller_for_thread(SentryCrashThread thread)
{
    size_t idx = thread % SENTRY_MAX_ASYNC_THREADS;
    sentry_async_caller_t *caller = &sentry_async_callers[idx];
    if (__atomic_load_n(&caller->thread, __ATOMIC_SEQ_CST) == thread) {
        sentry_async_backtrace_t *backtrace = __atomic_load_n(&caller->backtrace, __ATOMIC_SEQ_CST);
        // we read the thread id *again*, if it is still the same, the backtrace pointer we
        // read in between is valid
        if (__atomic_load_n(&caller->thread, __ATOMIC_SEQ_CST) == thread) {
            return backtrace;
        }
    }
    return NULL;
}

static bool
sentry__set_async_caller_for_thread(SentryCrashThread thread_slot, SentryCrashThread old_value,
    SentryCrashThread new_value, sentry_async_backtrace_t *backtrace)
{
    size_t idx = thread_slot % SENTRY_MAX_ASYNC_THREADS;
    sentry_async_caller_t *caller = &sentry_async_callers[idx];

    SentryCrashThread expected = old_value;
    bool success = __atomic_compare_exchange_n(
        &caller->thread, &expected, new_value, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);

    if (success) {
        __atomic_store_n(&caller->backtrace, backtrace, __ATOMIC_SEQ_CST);
    }

    return success;
}

void
sentry__async_backtrace_incref(sentry_async_backtrace_t *bt)
{
    if (!bt) {
        return;
    }
    __atomic_fetch_add(&bt->refcount, 1, __ATOMIC_SEQ_CST);
}

void
sentry__async_backtrace_decref(sentry_async_backtrace_t *bt)
{
    if (!bt) {
        return;
    }
    if (__atomic_fetch_add(&bt->refcount, -1, __ATOMIC_SEQ_CST) == 1) {
        sentry__async_backtrace_decref(bt->async_caller);
        free(bt);
    }
}

sentry_async_backtrace_t *
sentry__async_backtrace_capture(void)
{
    sentry_async_backtrace_t *bt = malloc(sizeof(sentry_async_backtrace_t));
    bt->refcount = 1;

    bt->len = backtrace(bt->backtrace, MAX_BACKTRACE_FRAMES);

    sentry_async_backtrace_t *caller = sentry_get_async_caller_for_thread(sentrycrashthread_self());
    sentry__async_backtrace_incref(caller);
    bt->async_caller = caller;

    return bt;
}

static void (*real_dispatch_async)(dispatch_queue_t queue, dispatch_block_t block);

void
sentry__hook_dispatch_async(dispatch_queue_t queue, dispatch_block_t block)
{
    // create a backtrace, capturing the async callsite
    sentry_async_backtrace_t *bt = sentry__async_backtrace_capture();

    return real_dispatch_async(queue, ^{
        SentryCrashThread thread = sentrycrashthread_self();

        // inside the async context, save the backtrace in a thread local for later consumption
        sentry__set_async_caller_for_thread(thread, (SentryCrashThread)NULL, thread, bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        sentry__set_async_caller_for_thread(thread, thread, (SentryCrashThread)NULL, NULL);
        sentry__async_backtrace_decref(bt);
    });
}

static void (*real_dispatch_async_f)(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work);

void
sentry__hook_dispatch_async_f(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work)
{
    sentry__hook_dispatch_async(queue, ^{ work(context); });
}

static void (*real_dispatch_after)(
    dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);

void
sentry__hook_dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block)
{
    // create a backtrace, capturing the async callsite
    sentry_async_backtrace_t *bt = sentry__async_backtrace_capture();

    return real_dispatch_after(when, queue, ^{
        SentryCrashThread thread = sentrycrashthread_self();

        // inside the async context, save the backtrace in a thread local for later consumption
        sentry__set_async_caller_for_thread(thread, (SentryCrashThread)NULL, thread, bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        sentry__set_async_caller_for_thread(thread, thread, (SentryCrashThread)NULL, NULL);
        sentry__async_backtrace_decref(bt);
    });
}

static void (*real_dispatch_after_f)(dispatch_time_t when, dispatch_queue_t queue,
    void *_Nullable context, dispatch_function_t work);

void
sentry__hook_dispatch_after_f(
    dispatch_time_t when, dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work)
{
    sentry__hook_dispatch_after(when, queue, ^{ work(context); });
}

static void (*real_dispatch_barrier_async)(dispatch_queue_t queue, dispatch_block_t block);

void
sentry__hook_dispatch_barrier_async(dispatch_queue_t queue, dispatch_block_t block)
{
    // create a backtrace, capturing the async callsite
    sentry_async_backtrace_t *bt = sentry__async_backtrace_capture();

    return real_dispatch_barrier_async(queue, ^{
        SentryCrashThread thread = sentrycrashthread_self();

        // inside the async context, save the backtrace in a thread local for later consumption
        sentry__set_async_caller_for_thread(thread, (SentryCrashThread)NULL, thread, bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        sentry__set_async_caller_for_thread(thread, thread, (SentryCrashThread)NULL, NULL);
        sentry__async_backtrace_decref(bt);
    });
}

static void (*real_dispatch_barrier_async_f)(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work);

void
sentry__hook_dispatch_barrier_async_f(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work)
{
    sentry__hook_dispatch_barrier_async(queue, ^{ work(context); });
}

static bool hooks_installed = false;

void
sentry_install_async_hooks(void)
{
    if (__atomic_exchange_n(&hooks_installed, true, __ATOMIC_SEQ_CST)) {
        true;
    }
    rebind_symbols(
        (struct rebinding[1]) {
            { "dispatch_async", sentry__hook_dispatch_async, (void *)&real_dispatch_async },
        },
        1);
    rebind_symbols(
        (struct rebinding[1]) {
            { "dispatch_async_f", sentry__hook_dispatch_async_f, (void *)&real_dispatch_async_f },
        },
        1);
    rebind_symbols(
        (struct rebinding[1]) {
            { "dispatch_after", sentry__hook_dispatch_after, (void *)&real_dispatch_after },
        },
        1);
    rebind_symbols(
        (struct rebinding[1]) {
            { "dispatch_after_f", sentry__hook_dispatch_after_f, (void *)&real_dispatch_after_f },
        },
        1);
    rebind_symbols(
        (struct rebinding[1]) {
            { "dispatch_barrier_async", sentry__hook_dispatch_barrier_async,
                (void *)&real_dispatch_barrier_async },
        },
        1);
    rebind_symbols(
        (struct rebinding[1]) {
            { "dispatch_barrier_async_f", sentry__hook_dispatch_barrier_async_f,
                (void *)&real_dispatch_barrier_async_f },
        },
        1);

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

// TODO: uninstall hooks
