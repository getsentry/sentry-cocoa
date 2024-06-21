#import "SentryMachLogging.hpp"

#define SENTRY_ASYNC_SAFE_LOG_DEBUG(fmt, ...)
#define SENTRY_ASYNC_SAFE_LOG_INFO(fmt, ...)
#define SENTRY_ASYNC_SAFE_LOG_WARN(fmt, ...)
#define SENTRY_ASYNC_SAFE_LOG_ERROR(fmt, ...)
#define SENTRY_ASYNC_SAFE_LOG_FATAL(fmt, ...)

#define SENTRY_ASYNC_SAFE_LOG_ERRNO_RETURN(statement)                                              \
    ({                                                                                             \
        errno = 0;                                                                                 \
        const auto __log_rv = (statement);                                                         \
        const int __log_errnum = errno;                                                            \
        if (__log_errnum != 0) {                                                                   \
            SENTRY_ASYNC_SAFE_LOG_ERROR(@"%s failed with code: %d, description: %s", #statement,   \
                __log_errnum, strerror(__log_errnum));                                             \
        }                                                                                          \
        __log_rv;                                                                                  \
    })

#define SENTRY_ASYNC_SAFE_LOG_KERN_RETURN(statement)                                               \
    ({                                                                                             \
        const kern_return_t __log_kr = statement;                                                  \
        if (__log_kr != KERN_SUCCESS) {                                                            \
            SENTRY_ASYNC_SAFE_LOG_ERROR("%s failed with kern return code: %d, description: %s",    \
                #statement, __log_kr, sentry::kernelReturnCodeDescription(__log_kr));              \
        }                                                                                          \
        __log_kr;                                                                                  \
    })

#define SENTRY_ASYNC_SAFE_LOG_MACH_MSG_RETURN(statement)                                           \
    ({                                                                                             \
        const mach_msg_return_t __log_mr = statement;                                              \
        if (__log_mr != MACH_MSG_SUCCESS) {                                                        \
            SENTRY_ASYNC_SAFE_LOG_ERROR(                                                           \
                "%s failed with mach_msg return code: %d, description: %s", #statement, __log_mr,  \
                sentry::machMessageReturnCodeDescription(__log_mr));                               \
        }                                                                                          \
        __log_mr;                                                                                  \
    })
