// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryAsyncSafeLog.h
//
//  Created by Karl Stenerud on 11-06-25.
//
//  Copyright (c) 2011 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#ifndef HDR_SENTRY_ASYNC_SAFE_LOG_H
#define HDR_SENTRY_ASYNC_SAFE_LOG_H

#define SENTRY_ASYNC_SAFE_LOG_C_BUFFER_SIZE 1024

/**
 * Buffer size for thread-safe strerror_r operations.
 *
 * POSIX doesn't specify a minimum buffer size for strerror_r. We use 1024 bytes to match
 * glibc's implementation, which uses a 1024-byte buffer for strerror() to ensure sufficient
 * space for error messages across all locales and systems. This provides a safe upper bound
 * while being reasonable for stack allocation since it's allocated per macro expansion.
 */
#define SENTRY_STRERROR_R_BUFFER_SIZE 1024

/**
 * In addition to writing to file, we can also write to the console. This is not safe to do from
 * actual async contexts, but can be helpful while running with the debugger attached in certain
 * cases. The logger will never write to the console if there is no debugger attached.
 * @warning Never commit a change of this definition to 1, or we compromise async-safety in
 * production crash reporting.
 */
#define SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE 0

#ifdef __cplusplus
extern "C" {
#endif

#include <errno.h>
#include <stdbool.h>
#include <string.h>

static char g_logFilename[1024];

void sentry_asyncLogC(const char *level, const char *file, int line, const char *fmt, ...);

#define i_SENTRY_ASYNC_SAFE_LOG sentry_asyncLogC

#define SENTRY_ASYNC_SAFE_LOG_LEVEL_NONE 0
#define SENTRY_ASYNC_SAFE_LOG_LEVEL_ERROR 10
#define SENTRY_ASYNC_SAFE_LOG_LEVEL_WARN 20
#define SENTRY_ASYNC_SAFE_LOG_LEVEL_INFO 30
#define SENTRY_ASYNC_SAFE_LOG_LEVEL_DEBUG 40
#define SENTRY_ASYNC_SAFE_LOG_LEVEL_TRACE 50

#define SENTRY_ASYNC_SAFE_LOG_LEVEL SENTRY_ASYNC_SAFE_LOG_LEVEL_ERROR

#define a_SENTRY_ASYNC_SAFE_LOG(LEVEL, FMT, ...)                                                   \
    i_SENTRY_ASYNC_SAFE_LOG(LEVEL, __FILE__, __LINE__, FMT, ##__VA_ARGS__)

// ============================================================================
#pragma mark - API -
// ============================================================================

/** Set the filename to log to.
 *
 * @param filename The file to write to (NULL = write to stdout).
 * @param overwrite If true, overwrite the log file.
 * @return 0 if successful, 1 otherwise.
 */
int sentry_asyncLogSetFileName(const char *filename, bool overwrite);

/** Tests if the logger would print at the specified level.
 *
 * @param LEVEL The level to test for. One of:
 *            SENTRY_ASYNC_SAFE_LOG_LEVEL_ERROR,
 *            SENTRY_ASYNC_SAFE_LOG_LEVEL_WARN,
 *            SENTRY_ASYNC_SAFE_LOG_LEVEL_INFO,
 *            SENTRY_ASYNC_SAFE_LOG_LEVEL_DEBUG,
 *            SENTRY_ASYNC_SAFE_LOG_LEVEL_TRACE,
 *
 * @return TRUE if the logger would print at the specified level.
 */
#define SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(LEVEL) (SENTRY_ASYNC_SAFE_LOG_LEVEL >= LEVEL)

/** Log an error.
 * Normal version prints out full context.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(SENTRY_ASYNC_SAFE_LOG_LEVEL_ERROR)
#    define SENTRY_ASYNC_SAFE_LOG_ERROR(FMT, ...)                                                  \
        a_SENTRY_ASYNC_SAFE_LOG("ERROR", FMT, ##__VA_ARGS__)
#else
#    define SENTRY_ASYNC_SAFE_LOG_ERROR(FMT, ...)
#endif

/** Log a warning.
 * Normal version prints out full context.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(SENTRY_ASYNC_SAFE_LOG_LEVEL_WARN)
#    define SENTRY_ASYNC_SAFE_LOG_WARN(FMT, ...)                                                   \
        a_SENTRY_ASYNC_SAFE_LOG("WARN ", FMT, ##__VA_ARGS__)
#else
#    define SENTRY_ASYNC_SAFE_LOG_WARN(FMT, ...)
#endif

/** Log an info message.
 * Normal version prints out full context.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(SENTRY_ASYNC_SAFE_LOG_LEVEL_INFO)
#    define SENTRY_ASYNC_SAFE_LOG_INFO(FMT, ...)                                                   \
        a_SENTRY_ASYNC_SAFE_LOG("INFO ", FMT, ##__VA_ARGS__)
#else
#    define SENTRY_ASYNC_SAFE_LOG_INFO(FMT, ...)
#endif

/** Log a debug message.
 * Normal version prints out full context.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(SENTRY_ASYNC_SAFE_LOG_LEVEL_DEBUG)
#    define SENTRY_ASYNC_SAFE_LOG_DEBUG(FMT, ...)                                                  \
        a_SENTRY_ASYNC_SAFE_LOG("DEBUG", FMT, ##__VA_ARGS__)
#else
#    define SENTRY_ASYNC_SAFE_LOG_DEBUG(FMT, ...)
#endif

/** Log a trace message.
 * Normal version prints out full context.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(SENTRY_ASYNC_SAFE_LOG_LEVEL_TRACE)
#    define SENTRY_ASYNC_SAFE_LOG_TRACE(FMT, ...)                                                  \
        a_SENTRY_ASYNC_SAFE_LOG("TRACE", FMT, ##__VA_ARGS__)
#else
#    define SENTRY_ASYNC_SAFE_LOG_TRACE(FMT, ...)
#endif

/**
 * Thread-safe version of strerror using strerror_r.
 * On macOS/iOS, strerror_r follows XSI-compliant version which returns int.
 * This macro evaluates to a pointer to a buffer containing the error string.
 * Each macro expansion uses a local variable, making it thread-safe.
 *
 * The buffer size is defined by SENTRY_STRERROR_R_BUFFER_SIZE (1024 bytes, matching glibc).
 *
 * @param ERRNUM The error number (e.g., errno).
 * @return Pointer to a thread-safe error string.
 */
#define SENTRY_STRERROR_R(ERRNUM)                                                                  \
    ({                                                                                             \
        char __strerror_buf[SENTRY_STRERROR_R_BUFFER_SIZE];                                        \
        if (strerror_r((ERRNUM), __strerror_buf, sizeof(__strerror_buf)) != 0) {                   \
            snprintf(__strerror_buf, sizeof(__strerror_buf), "Unknown error %d", (ERRNUM));        \
        }                                                                                          \
        __strerror_buf;                                                                            \
    })

/**
 * If @c errno is set to a non-zero value after @c statement finishes executing,
 * the error value is logged, and the original return value of @c statement is
 * returned.
 */
#define SENTRY_ASYNC_SAFE_LOG_ERRNO_RETURN(statement)                                              \
    ({                                                                                             \
        errno = 0;                                                                                 \
        const auto __log_rv = (statement);                                                         \
        const int __log_errnum = errno;                                                            \
        if (__log_errnum != 0) {                                                                   \
            SENTRY_ASYNC_SAFE_LOG_ERROR("%s failed with code: %d, description: %s", #statement,    \
                __log_errnum, SENTRY_STRERROR_R(__log_errnum));                                    \
        }                                                                                          \
        __log_rv;                                                                                  \
    })

#ifdef __cplusplus
}
#endif

#endif // HDR_SENTRY_ASYNC_SAFE_LOG_H
