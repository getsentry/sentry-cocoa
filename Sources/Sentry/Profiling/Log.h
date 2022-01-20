// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#define SPECTO_LOG_LEVEL_TRACE SPDLOG_LEVEL_TRACE
#define SPECTO_LOG_LEVEL_DEBUG SPDLOG_LEVEL_DEBUG
#define SPECTO_LOG_LEVEL_INFO SPDLOG_LEVEL_INFO
#define SPECTO_LOG_LEVEL_WARN SPDLOG_LEVEL_WARN
#define SPECTO_LOG_LEVEL_ERROR SPDLOG_LEVEL_ERROR
#define SPECTO_LOG_LEVEL_CRITICAL SPDLOG_LEVEL_CRITICAL
#define SPECTO_LOG_LEVEL_OFF SPDLOG_LEVEL_OFF

#if !defined(SPECTO_ACTIVE_LOG_LEVEL)
#if defined(SPECTO_ENV_PRODUCTION)
#define SPECTO_ACTIVE_LOG_LEVEL SPECTO_LOG_LEVEL_DEBUG
#else
#define SPECTO_ACTIVE_LOG_LEVEL SPECTO_LOG_LEVEL_TRACE
#endif
#endif

#define SPDLOG_ACTIVE_LEVEL SPECTO_ACTIVE_LOG_LEVEL

//#include "fmt/format.h"
#include "spdlog/spdlog.h"

#include <cerrno>
#include <cstring>
#include <string>
#include <unistd.h>
#include <vector>

#if !defined(SPECTO_ENV_PRODUCTION)
#define SPECTO_LOG_TRACE(...) SPDLOG_LOGGER_TRACE(specto::getLogger(), __VA_ARGS__)
#else
#define SPECTO_LOG_TRACE(...)
#endif

#define SPECTO_LOG_DEBUG(...) SPDLOG_LOGGER_DEBUG(specto::getLogger(), __VA_ARGS__)
#define SPECTO_LOG_INFO(...) SPDLOG_LOGGER_INFO(specto::getLogger(), __VA_ARGS__)
#define SPECTO_LOG_WARN(...) SPDLOG_LOGGER_WARN(specto::getLogger(), __VA_ARGS__)
#define SPECTO_LOG_ERROR(...) SPDLOG_LOGGER_ERROR(specto::getLogger(), __VA_ARGS__)
#define SPECTO_LOG_CRITICAL(...) SPDLOG_LOGGER_CRITICAL(specto::getLogger(), __VA_ARGS__)

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

namespace specto {
/**
 * Configures the logger with a file path to write log output to. This should be called
 * before any other Specto API's are used.
 * @param logFilePath The path to write logs to.
 * @param additionalSinks Additional sinks to add to the logger.
 * @param debug True to set the system log level to DEBUG, otherwise will be set to WARN.
 *
 * @warning This is *not* safe to call concurrently with `getLogger`.
 */
#if defined(SPECTO_ENV_PRODUCTION)
void configureLogger(const std::string &logFilePath,
                     std::vector<spdlog::sink_ptr> additionalSinks,
                     bool debug = false);
#else
void configureLogger(const std::string &logFilePath,
                     std::vector<spdlog::sink_ptr> additionalSinks,
                     bool debug = true);
#endif

/**
 * Returns the default logger instance. This function is guaranteed to return a non-null
 * pointer. If called before `configureLogger`, this will return the default spdlog logger
 * instance. If called after `configureLogger`, this returns the Specto-configured logger.
 *
 * @warning This is *not* safe to call concurrently with `configureLogger`.
 *
 * @note This logger instance is intentionally leaked, and is never deallocated.
 */
spdlog::logger *getLogger();

void setLogLevel(spdlog::level::level_enum level);
} // namespace specto
