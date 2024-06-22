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

/**
 * SentryAsyncSafeLog
 * ========
 *
 * Prints log entries to the console consisting of:
 * - Level (Error, Warn, Info, Debug, Trace)
 * - File
 * - Line
 * - Function
 * - Message
 *
 * Allows setting the minimum logging level in the preprocessor.
 *
 * Works in C or Objective-C contexts, with or without ARC, using CLANG or GCC.
 *
 *
 * =====
 * USAGE
 * =====
 *
 * Set the log level in your "Preprocessor Macros" build setting. You may choose
 * TRACE, DEBUG, INFO, WARN, ERROR. If nothing is set, it defaults to ERROR.
 *
 * Example: SENTRY_ASYNC_SAFE_LOG_LEVEL=WARN
 *
 * Anything below the level specified for SENTRY_ASYNC_SAFE_LOG_LEVEL will not be
 * compiled or printed.
 *
 *
 * Next, include the header file:
 *
 * #include "SentryAsyncSafeLog.h"
 *
 *
 * Next, call the logger functions from your code (using objective-c strings
 * in objective-C files and regular strings in regular C files):
 *
 * Code:
 *    SENTRY_ASYNC_SAFE_LOG_ERROR(@"Some error message");
 *
 * Prints:
 *    2011-07-16 05:41:01.379 TestApp[4439:f803] ERROR: SomeClass.m (21):
 * -[SomeFunction]: Some error message
 *
 * Code:
 *    SENTRY_ASYNC_SAFE_LOG_INFO(@"Info about %@", someObject);
 *
 * Prints:
 *    2011-07-16 05:44:05.239 TestApp[4473:f803] INFO : SomeClass.m (20):
 * -[SomeFunction]: Info about <NSObject: 0xb622840>
 *
 *
 * The "BASIC" versions of the macros behave exactly like NSLog() or printf(),
 * except they respect the SENTRY_ASYNC_SAFE_LOG_LEVEL setting:
 *
 * Code:
 *    SENTRY_ASYNC_SAFE_LOG_BASIC_ERROR(@"A basic log entry");
 *
 * Prints:
 *    2011-07-16 05:44:05.916 TestApp[4473:f803] A basic log entry
 *
 *
 * NOTE: In C files, use "" instead of @"" in the format field. Logging calls
 *       in C files do not print the NSLog preamble:
 *
 * Objective-C version:
 *    SENTRY_ASYNC_SAFE_LOG_ERROR(@"Some error message");
 *
 *    2011-07-16 05:41:01.379 TestApp[4439:f803] ERROR: SomeClass.m (21):
 * -[SomeFunction]: Some error message
 *
 * C version:
 *    SENTRY_ASYNC_SAFE_LOG_ERROR("Some error message");
 *
 *    ERROR: SomeClass.c (21): SomeFunction(): Some error message
 *
 *
 * =============
 * LOCAL LOGGING
 * =============
 *
 * You can control logging messages at the local file level using the
 * "SENTRY_ASYNC_SAFE_LOG_LOCAL_LEVEL" define. Note that it must be defined BEFORE
 * including SentryAsyncSafeLog.h
 *
 * The SENTRY_ASYNC_SAFE_LOG_XX() and SENTRY_ASYNC_SAFE_LOG_BASIC_XX() macros will print out
 * based on the LOWER of SENTRY_ASYNC_SAFE_LOG_LEVEL and
 * SENTRY_ASYNC_SAFE_LOG_LOCAL_LEVEL, so if SENTRY_ASYNC_SAFE_LOG_LEVEL is DEBUG and
 * SENTRY_ASYNC_SAFE_LOG_LOCAL_LEVEL is TRACE, it will print all the way down to the
 * trace level for the local file where SENTRY_ASYNC_SAFE_LOG_LOCAL_LEVEL was
 * defined, and to the debug level everywhere else.
 *
 * Example:
 *
 * // SENTRY_ASYNC_SAFE_LOG_LOCAL_LEVEL, if defined, MUST come BEFORE including
 * SentryAsyncSafeLog.h #define SENTRY_ASYNC_SAFE_LOG_LOCAL_LEVEL TRACE #import
 * "SentryAsyncSafeLog.h"
 */

#define SENTRY_ASYNC_SAFE_LOG_C_BUFFER_SIZE 1024

/**
 * In addition to writing to file, we can also write to the console. This is not safe to do from
 * actual async contexts, but can be helpful while running with the debugger attached in certain
 * cases. The logger will never write to the console if there is no debugger attached.
 * @warning Never commit a change of this definition to 1, or we compromise async-safety in
 * production crash reporting.
 */
#define SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE 0

// ============================================================================
#pragma mark - (internal) -
// ============================================================================

#ifndef HDR_SENTRY_ASYNC_SAFE_LOG_H
#    define HDR_SENTRY_ASYNC_SAFE_LOG_H

#    ifdef __cplusplus
extern "C" {
#    endif

#    include <stdbool.h>

void sentry_asyncLogC(
    const char *level, const char *file, int line, const char *function, const char *fmt, ...);

void sentry_asyncLogCBasic(const char *fmt, ...);

#    define i_SENTRY_ASYNC_SAFE_LOG_FULL sentry_asyncLogC
#    define i_SENTRY_ASYNC_SAFE_LOG_BASIC sentry_asyncLogCBasic

/* Back up any existing defines by the same name */
#    ifdef SENTRY_ASYNC_SAFE_LOG_NONE
#        define SENTRY_ASYNC_SAFE_LOG_BAK_NONE SENTRY_ASYNC_SAFE_LOG_NONE
#        undef SENTRY_ASYNC_SAFE_LOG_NONE
#    endif
#    ifdef ERROR
#        define SENTRY_ASYNC_SAFE_LOG_BAK_ERROR ERROR
#        undef ERROR
#    endif
#    ifdef WARN
#        define SENTRY_ASYNC_SAFE_LOG_BAK_WARN WARN
#        undef WARN
#    endif
#    ifdef INFO
#        define SENTRY_ASYNC_SAFE_LOG_BAK_INFO INFO
#        undef INFO
#    endif
#    ifdef DEBUG
#        define SENTRY_ASYNC_SAFE_LOG_BAK_DEBUG DEBUG
#        undef DEBUG
#    endif
#    ifdef TRACE
#        define SENTRY_ASYNC_SAFE_LOG_BAK_TRACE TRACE
#        undef TRACE
#    endif

#    define SENTRY_ASYNC_SAFE_LOG_LEVEL_NONE 0
#    define SENTRY_ASYNC_SAFE_LOG_LEVEL_ERROR 10
#    define SENTRY_ASYNC_SAFE_LOG_LEVEL_WARN 20
#    define SENTRY_ASYNC_SAFE_LOG_LEVEL_INFO 30
#    define SENTRY_ASYNC_SAFE_LOG_LEVEL_DEBUG 40
#    define SENTRY_ASYNC_SAFE_LOG_LEVEL_TRACE 50

#    define SENTRY_ASYNC_SAFE_LOG_NONE SENTRY_ASYNC_SAFE_LOG_LEVEL_NONE
#    define ERROR SENTRY_ASYNC_SAFE_LOG_LEVEL_ERROR
#    define WARN SENTRY_ASYNC_SAFE_LOG_LEVEL_WARN
#    define INFO SENTRY_ASYNC_SAFE_LOG_LEVEL_INFO
#    define DEBUG SENTRY_ASYNC_SAFE_LOG_LEVEL_DEBUG
#    define TRACE SENTRY_ASYNC_SAFE_LOG_LEVEL_TRACE

#    ifndef SENTRY_ASYNC_SAFE_LOG_LEVEL
#        define SENTRY_ASYNC_SAFE_LOG_LEVEL SENTRY_ASYNC_SAFE_LOG_LEVEL_ERROR
#    endif

#    ifndef SENTRY_ASYNC_SAFE_LOG_LOCAL_LEVEL
#        define SENTRY_ASYNC_SAFE_LOG_LOCAL_LEVEL SENTRY_ASYNC_SAFE_LOG_LEVEL_TRACE
#    endif

#    define a_SENTRY_ASYNC_SAFE_LOG_FULL(LEVEL, FMT, ...)                                          \
        i_SENTRY_ASYNC_SAFE_LOG_FULL(                                                              \
            LEVEL, __FILE__, __LINE__, __PRETTY_FUNCTION__, FMT, ##__VA_ARGS__)

// ============================================================================
#    pragma mark - API -
// ============================================================================

/** Set the filename to log to.
 *
 * @param filename The file to write to (NULL = write to stdout).
 *
 * @param overwrite If true, overwrite the log file.
 */
bool sentry_asyncLogSetFileName(const char *filename, bool overwrite);

/** Clear the log file. */
bool sentry_asyncLogClearLogFile(void);

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
#    define SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(LEVEL)                                           \
        (SENTRY_ASYNC_SAFE_LOG_LEVEL >= LEVEL || SENTRY_ASYNC_SAFE_LOG_LOCAL_LEVEL >= LEVEL)

/** Log a message regardless of the log settings.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#    define SENTRY_ASYNC_SAFE_LOG_ALWAYS(FMT, ...)                                                 \
        a_SENTRY_ASYNC_SAFE_LOG_FULL("FORCE", FMT, ##__VA_ARGS__)
#    define SENTRY_ASYNC_SAFE_LOG_BASIC_ALWAYS(FMT, ...)                                           \
        i_SENTRY_ASYNC_SAFE_LOG_BASIC(FMT, ##__VA_ARGS__)

/** Log an error.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#    if SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(SENTRY_ASYNC_SAFE_LOG_LEVEL_ERROR)
#        define SENTRY_ASYNC_SAFE_LOG_ERROR(FMT, ...)                                              \
            a_SENTRY_ASYNC_SAFE_LOG_FULL("ERROR", FMT, ##__VA_ARGS__)
#        define SENTRY_ASYNC_SAFE_LOG_BASIC_ERROR(FMT, ...)                                        \
            i_SENTRY_ASYNC_SAFE_LOG_BASIC(FMT, ##__VA_ARGS__)
#    else
#        define SENTRY_ASYNC_SAFE_LOG_ERROR(FMT, ...)
#        define SENTRY_ASYNC_SAFE_LOG_BASIC_ERROR(FMT, ...)
#    endif

/** Log a warning.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#    if SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(SENTRY_ASYNC_SAFE_LOG_LEVEL_WARN)
#        define SENTRY_ASYNC_SAFE_LOG_WARN(FMT, ...)                                               \
            a_SENTRY_ASYNC_SAFE_LOG_FULL("WARN ", FMT, ##__VA_ARGS__)
#        define SENTRY_ASYNC_SAFE_LOG_BASIC_WARN(FMT, ...)                                         \
            i_SENTRY_ASYNC_SAFE_LOG_BASIC(FMT, ##__VA_ARGS__)
#    else
#        define SENTRY_ASYNC_SAFE_LOG_WARN(FMT, ...)
#        define SENTRY_ASYNC_SAFE_LOG_BASIC_WARN(FMT, ...)
#    endif

/** Log an info message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#    if SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(SENTRY_ASYNC_SAFE_LOG_LEVEL_INFO)
#        define SENTRY_ASYNC_SAFE_LOG_INFO(FMT, ...)                                               \
            a_SENTRY_ASYNC_SAFE_LOG_FULL("INFO ", FMT, ##__VA_ARGS__)
#        define SENTRY_ASYNC_SAFE_LOG_BASIC_INFO(FMT, ...)                                         \
            i_SENTRY_ASYNC_SAFE_LOG_BASIC(FMT, ##__VA_ARGS__)
#    else
#        define SENTRY_ASYNC_SAFE_LOG_INFO(FMT, ...)
#        define SENTRY_ASYNC_SAFE_LOG_BASIC_INFO(FMT, ...)
#    endif

/** Log a debug message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#    if SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(SENTRY_ASYNC_SAFE_LOG_LEVEL_DEBUG)
#        define SENTRY_ASYNC_SAFE_LOG_DEBUG(FMT, ...)                                              \
            a_SENTRY_ASYNC_SAFE_LOG_FULL("DEBUG", FMT, ##__VA_ARGS__)
#        define SENTRY_ASYNC_SAFE_LOG_BASIC_DEBUG(FMT, ...)                                        \
            i_SENTRY_ASYNC_SAFE_LOG_BASIC(FMT, ##__VA_ARGS__)
#    else
#        define SENTRY_ASYNC_SAFE_LOG_DEBUG(FMT, ...)
#        define SENTRY_ASYNC_SAFE_LOG_BASIC_DEBUG(FMT, ...)
#    endif

/** Log a trace message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#    if SENTRY_ASYNC_SAFE_LOG_PRINTS_AT_LEVEL(SENTRY_ASYNC_SAFE_LOG_LEVEL_TRACE)
#        define SENTRY_ASYNC_SAFE_LOG_TRACE(FMT, ...)                                              \
            a_SENTRY_ASYNC_SAFE_LOG_FULL("TRACE", FMT, ##__VA_ARGS__)
#        define SENTRY_ASYNC_SAFE_LOG_BASIC_TRACE(FMT, ...)                                        \
            i_SENTRY_ASYNC_SAFE_LOG_BASIC(FMT, ##__VA_ARGS__)
#    else
#        define SENTRY_ASYNC_SAFE_LOG_TRACE(FMT, ...)
#        define SENTRY_ASYNC_SAFE_LOG_BASIC_TRACE(FMT, ...)
#    endif

// ============================================================================
#    pragma mark - (internal) -
// ============================================================================

/* Put everything back to the way we found it. */
#    undef ERROR
#    ifdef SENTRY_ASYNC_SAFE_LOG_BAK_ERROR
#        define ERROR SENTRY_ASYNC_SAFE_LOG_BAK_ERROR
#        undef SENTRY_ASYNC_SAFE_LOG_BAK_ERROR
#    endif
#    undef WARNING
#    ifdef SENTRY_ASYNC_SAFE_LOG_BAK_WARN
#        define WARNING SENTRY_ASYNC_SAFE_LOG_BAK_WARN
#        undef SENTRY_ASYNC_SAFE_LOG_BAK_WARN
#    endif
#    undef INFO
#    ifdef SENTRY_ASYNC_SAFE_LOG_BAK_INFO
#        define INFO SENTRY_ASYNC_SAFE_LOG_BAK_INFO
#        undef SENTRY_ASYNC_SAFE_LOG_BAK_INFO
#    endif
#    undef DEBUG
#    ifdef SENTRY_ASYNC_SAFE_LOG_BAK_DEBUG
#        define DEBUG SENTRY_ASYNC_SAFE_LOG_BAK_DEBUG
#        undef SENTRY_ASYNC_SAFE_LOG_BAK_DEBUG
#    endif
#    undef TRACE
#    ifdef SENTRY_ASYNC_SAFE_LOG_BAK_TRACE
#        define TRACE SENTRY_ASYNC_SAFE_LOG_BAK_TRACE
#        undef SENTRY_ASYNC_SAFE_LOG_BAK_TRACE
#    endif

#    ifdef __cplusplus
}
#    endif

#endif // HDR_SENTRY_ASYNC_SAFE_LOG_H
