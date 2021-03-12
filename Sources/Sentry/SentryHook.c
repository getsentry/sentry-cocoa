#include "SentryHook.h"
#include "fishhook.h"
#include <dispatch/dispatch.h>
#include <execinfo.h>
#include <pthread.h>

// TODO: use some kind of hashtable-like structure for the threads maybe?
static __thread sentry_async_backtrace_t *threadlocal_async_caller = NULL;

sentry_async_backtrace_t* sentry_get_async_caller_for_thread(SentryCrashThread thread) {
    // TODO:
    (void)thread;
    return threadlocal_async_caller;
}


static inline long
sentry__atomic_fetch_and_add(volatile long *val, long diff)
{
    return __atomic_fetch_add(val, diff, __ATOMIC_SEQ_CST);
}

void sentry__async_backtrace_incref(sentry_async_backtrace_t* bt) {
    if (!bt) {
        return;
    }
    sentry__atomic_fetch_and_add(&bt->refcount, 1);
}

void sentry__async_backtrace_decref(sentry_async_backtrace_t* bt) {
    if (!bt) {
        return;
    }
    if (sentry__atomic_fetch_and_add(&bt->refcount, -1) == 1) {
        sentry__async_backtrace_decref(bt->async_caller);
        free(bt);
    }
}

static void
(*real_dispatch_async)(dispatch_queue_t queue, dispatch_block_t block);

sentry_async_backtrace_t* sentry__async_backtrace_capture(void) {
    sentry_async_backtrace_t *bt = malloc(sizeof(sentry_async_backtrace_t));
    bt->refcount = 1;
    
    bt->len = backtrace(bt->backtrace, MAX_BACKTRACE_FRAMES);
    
    sentry_async_backtrace_t *caller = sentry_get_async_caller_for_thread(sentrycrashthread_self());
    sentry__async_backtrace_incref(caller);
    bt->async_caller = caller;
    
    return bt;
}

void sentry__hook_dispatch_async(dispatch_queue_t queue, dispatch_block_t block) {
    // create a backtrace, capturing the async callsite
    sentry_async_backtrace_t *bt = sentry__async_backtrace_capture();
    
    return real_dispatch_async(queue, ^{
        SentryCrashThread thread = sentrycrashthread_self();
        // TODO: use thread
        (void)thread;
        
        // inside the async context, save the backtrace in a thread local for later consumption
        threadlocal_async_caller = bt;
        
        // call through to the original block
        block();
        
        // and decref our current backtrace
        sentry__async_backtrace_decref(bt);
        threadlocal_async_caller = NULL;
    });
}

void sentry_install_async_hooks(void)
{
    rebind_symbols((struct rebinding[1]){
        {"dispatch_async", sentry__hook_dispatch_async, (void *)&real_dispatch_async},
    }, 1);
    // TODO:
    //dispatch_async_f
    //dispatch_after
    //dispatch_after_f
}
