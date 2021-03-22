#include "SentryHook.h"
#include "fishhook.h"
#include <dispatch/dispatch.h>
#include <execinfo.h>
#include <pthread.h>
#include <mach/mach.h>

// NOTE on accessing thread-locals across threads:
// We save the async stacktrace as a thread local when dispatching async calls,
// but the various crash handlers need to access these thread-locals across threads
// sometimes, which we do here:
// While `pthread_t` is an opaque type, the offset of `thread specific data` (tsd)
// is fixed due to backwards compatibility.
// See: https://github.com/apple/darwin-libpthread/blob/c60d249cc84dfd6097a7e71c68a36b47cbe076d1/src/types_internal.h#L409-L432

#if __LP64__
#define TSD_OFFSET 224
#else
#define TSD_OFFSET 176
#endif

static pthread_key_t async_caller_key = 0;

sentry_async_backtrace_t *
sentry_get_async_caller_for_thread(SentryCrashThread thread)
{
    const pthread_t pthread = pthread_from_mach_thread_np((thread_t)thread);
    void **tsd_slots = (void*)((uint8_t*)pthread + TSD_OFFSET);
    return (sentry_async_backtrace_t *)tsd_slots[async_caller_key];
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

    sentry_async_backtrace_t *caller =
        pthread_getspecific(async_caller_key);
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
        // inside the async context, save the backtrace in a thread local for later consumption
        pthread_setspecific(async_caller_key, bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        pthread_setspecific(async_caller_key, NULL);
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
        // inside the async context, save the backtrace in a thread local for later consumption
        pthread_setspecific(async_caller_key, bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        pthread_setspecific(async_caller_key, NULL);
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
        // inside the async context, save the backtrace in a thread local for later consumption
        pthread_setspecific(async_caller_key, bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        pthread_setspecific(async_caller_key, NULL);
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
        return;
    }
    if (pthread_key_create(&async_caller_key, NULL) != 0)    {
        return;
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
