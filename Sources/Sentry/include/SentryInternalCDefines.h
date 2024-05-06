typedef unsigned long long bytes;

/**
 * For disabling the thread sanitizer for a method
 */
#if defined(__has_feature)
#    if __has_feature(thread_sanitizer)
#        define SENTRY_DISABLE_THREAD_SANITIZER(message) __attribute__((no_sanitize("thread")))
#    else
#        define SENTRY_DISABLE_THREAD_SANITIZER(message)
#    endif
#else
#    define SENTRY_DISABLE_THREAD_SANITIZER(message)
#endif
