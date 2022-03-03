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
