// Copyright (c) Specto Inc. All rights reserved.

#pragma once

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
#define SPECTO_LOG_ERROR_RETURN(statement)                               \
    ({                                                                   \
        const int __log_errnum = statement;                              \
        if (__log_errnum != 0) {                                         \
            SPECTO_LOG_ERROR("{} failed with code: {}, description: {}", \
                             #statement,                                 \
                             __log_errnum,                               \
                             std::strerror(__log_errnum));               \
        }                                                                \
        __log_errnum;                                                    \
    })

/**
 * If `errno` is set to a non-zero value after `statement` finishes executing,
 * the error value is logged, and the original return value of `statement` is
 * returned.
 */
#define SPECTO_LOG_ERRNO(statement)                                      \
    ({                                                                   \
        errno = 0;                                                       \
        const auto __log_rv = (statement);                               \
        const int __log_errnum = errno;                                  \
        if (__log_errnum != 0) {                                         \
            SPECTO_LOG_ERROR("{} failed with code: {}, description: {}", \
                             #statement,                                 \
                             __log_errnum,                               \
                             std::strerror(__log_errnum));               \
        }                                                                \
        __log_rv;                                                        \
    })

/**
 * If `errno` is set to a non-zero value after `statement` finishes executing,
 * the error value is logged, and the value of `errno` is returned, since the
 * statement does not have a return value.
 */
#define SPECTO_LOG_ERRNO_VOID_RETURN(statement)                          \
    ({                                                                   \
        errno = 0;                                                       \
        (void)statement;                                                 \
        const int __log_errnum = errno;                                  \
        if (__log_errnum != 0) {                                         \
            SPECTO_LOG_ERROR("{} failed with code: {}, description: {}", \
                             #statement,                                 \
                             __log_errnum,                               \
                             std::strerror(__log_errnum));               \
        }                                                                \
        __log_errnum;                                                    \
    })

// write(2) is async signal safe:
// http://man7.org/linux/man-pages/man7/signal-safety.7.html
#define __SPECTO_LOG_ASYNC_SAFE(fd, str) write(fd, str, sizeof(str) - 1)
#define SPECTO_LOG_ASYNC_SAFE_INFO(str) __SPECTO_LOG_ASYNC_SAFE(STDOUT_FILENO, str "\n")
#define SPECTO_LOG_ASYNC_SAFE_ERROR(str) __SPECTO_LOG_ASYNC_SAFE(STDERR_FILENO, str "\n")
