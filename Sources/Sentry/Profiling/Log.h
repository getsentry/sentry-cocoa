// Copyright (c) Specto Inc. All rights reserved.

#pragma once

// from cpp/log/src/Log.h

#define SPECTO_LOG_TRACE(...)
#define SPECTO_LOG_DEBUG(...)
#define SPECTO_LOG_INFO(...)
#define SPECTO_LOG_WARN(...)
#define SPECTO_LOG_ERROR(...)
#define SPECTO_LOG_CRITICAL(...)

#include <cerrno>
#include <cstring>
#include <string>
#include <unistd.h>
#include <vector>

/**
 * Logs the error code returned by executing `statement`, and returns the
 * error code (i.e. returns the return value of `statement`).
 */
#define SPECTO_LOG_ERROR_RETURN(statement)                                                         \
    ({                                                                                             \
        const int __log_errnum = statement;                                                        \
        if (__log_errnum != 0) {                                                                   \
            SPECTO_LOG_ERROR("{} failed with code: {}, description: {}", #statement, __log_errnum, \
                std::strerror(__log_errnum));                                                      \
        }                                                                                          \
        __log_errnum;                                                                              \
    })

/**
 * If `errno` is set to a non-zero value after `statement` finishes executing,
 * the error value is logged, and the original return value of `statement` is
 * returned.
 */
#define SPECTO_LOG_ERRNO(statement)                                                                \
    ({                                                                                             \
        errno = 0;                                                                                 \
        const auto __log_rv = (statement);                                                         \
        const int __log_errnum = errno;                                                            \
        if (__log_errnum != 0) {                                                                   \
            SPECTO_LOG_ERROR("{} failed with code: {}, description: {}", #statement, __log_errnum, \
                std::strerror(__log_errnum));                                                      \
        }                                                                                          \
        __log_rv;                                                                                  \
    })

/**
 * If `errno` is set to a non-zero value after `statement` finishes executing,
 * the error value is logged, and the value of `errno` is returned, since the
 * statement does not have a return value.
 */
#define SPECTO_LOG_ERRNO_VOID_RETURN(statement)                                                    \
    ({                                                                                             \
        errno = 0;                                                                                 \
        (void)statement;                                                                           \
        const int __log_errnum = errno;                                                            \
        if (__log_errnum != 0) {                                                                   \
            SPECTO_LOG_ERROR("{} failed with code: {}, description: {}", #statement, __log_errnum, \
                std::strerror(__log_errnum));                                                      \
        }                                                                                          \
        __log_errnum;                                                                              \
    })

// write(2) is async signal safe:
// http://man7.org/linux/man-pages/man7/signal-safety.7.html
#define __SPECTO_LOG_ASYNC_SAFE(fd, str) write(fd, str, sizeof(str) - 1)
#define SPECTO_LOG_ASYNC_SAFE_INFO(str) __SPECTO_LOG_ASYNC_SAFE(STDOUT_FILENO, str "\n")
#define SPECTO_LOG_ASYNC_SAFE_ERROR(str) __SPECTO_LOG_ASYNC_SAFE(STDERR_FILENO, str "\n")

// from objc/log/src/Log.h

#define SPECTO_LOG_WARN_OBJC(...)                                                                  \
    SPECTO_LOG_WARN([NSString stringWithFormat:__VA_ARGS__].UTF8String)
#define SPECTO_LOG_ERROR_OBJC(...)                                                                 \
    SPECTO_LOG_ERROR([NSString stringWithFormat:__VA_ARGS__].UTF8String)
#define SPECTO_LOG_INFO_OBJC(...)                                                                  \
    SPECTO_LOG_INFO([NSString stringWithFormat:__VA_ARGS__].UTF8String)
#define SPECTO_LOG_DEBUG_OBJC(...)                                                                 \
    SPECTO_LOG_DEBUG([NSString stringWithFormat:__VA_ARGS__].UTF8String)

#if !defined(SPECTO_ENV_PRODUCTION)
#    define SPECTO_LOG_TRACE_OBJC(...)                                                             \
        SPECTO_LOG_TRACE([NSString stringWithFormat:__VA_ARGS__].UTF8String)
#else
#    define SPECTO_LOG_TRACE_OBJC(...)
#endif

/** Logs a warning and fails an assertion with a message, without checking a condition. */
#if defined(SPECTO_TEST_ENVIRONMENT)
#    define SPECTO_FAIL_ASSERT(...)                                                                \
        ({                                                                                         \
            SPECTO_LOG_WARN_OBJC(__VA_ARGS__);                                                     \
            NSCAssert(NO, __VA_ARGS__);                                                            \
        })
#else
#    define SPECTO_FAIL_ASSERT(...) ({ SPECTO_LOG_WARN_OBJC(__VA_ARGS__); })
#endif

/**
 * Test a condition and if it fails, log and abort; return the value of the condition
 * so execution may be branched in the event of a failure.
 */
#if defined(SPECTO_TEST_ENVIRONMENT)
#    define SPECTO_ASSERT(cond, ...)                                                               \
        ({                                                                                         \
            const auto __cond_result = (cond);                                                     \
            if (!__cond_result) {                                                                  \
                SPECTO_LOG_WARN_OBJC(__VA_ARGS__);                                                 \
            }                                                                                      \
            (__cond_result);                                                                       \
        })
#else
#    define SPECTO_ASSERT(cond, ...)                                                               \
        ({                                                                                         \
            const auto __cond_result = (cond);                                                     \
            if (!__cond_result) {                                                                  \
                SPECTO_LOG_WARN_OBJC(__VA_ARGS__);                                                 \
                NSCAssert(NO, __VA_ARGS__);                                                        \
            }                                                                                      \
            (__cond_result);                                                                       \
        })
#endif

#define SPECTO_ASSERT_TYPE(object, klass, ...)                                                     \
    SPECTO_ASSERT([object isKindOfClass:[klass class]], __VA_ARGS__)

#define SPECTO_ASSERT_NULL(value, ...) SPECTO_ASSERT(value == nil, __VA_ARGS__)

#define SPECTO_ASSERT_NOT_NULL(value, ...) SPECTO_ASSERT(value != nil, __VA_ARGS__)
