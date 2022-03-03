#pragma once

#define SPECTO_LOG_DEBUG(...)
#define SPECTO_LOG_WARN(...)
#define SPECTO_LOG_ERROR(...)

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
