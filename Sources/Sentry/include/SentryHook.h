#ifndef SENRTY_HOOK_h
#define SENRTY_HOOK_h

#include <stdint.h>

#define MAX_BACKTRACE_FRAMES 128

/**
 * This represents a stacktrace that can optionally have an `async_caller` and form an async call chain.
 */
typedef struct sentry_async_backtrace_s sentry_async_backtrace_t;
struct sentry_async_backtrace_s {
    long refcount;
    sentry_async_backtrace_t* async_caller;
    size_t len;
    void* backtrace[MAX_BACKTRACE_FRAMES];
};

/**
 * Returns the async caller of the current calling context, if any.
 */
sentry_async_backtrace_t*
sentry_get_async_caller(void);

/**
 * Installs the various async hooks that sentry offers.
 *
 * The hooks work like this:
 * We overwrite the `libdispatch/dispatch_async`, etc functions with our own wrapper.
 * Those wrappers create a stacktrace in the calling thread, and pass that stacktrace via a closure into the callee thread.
 * In the callee, the stacktrace is saved as a thread-local before invoking the original block/function.
 * The thread local can be accessed for inspection and is also used for chained async calls.
 */
void sentry_install_async_hooks(void);

#endif /* SENRTY_HOOK_h */
