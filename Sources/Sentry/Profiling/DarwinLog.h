// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#ifndef __APPLE__
#    error Non-Apple platforms are not supported!
#endif

#include "Log.h"

#include <mach/kern_return.h>
#include <mach/message.h>

namespace specto {
namespace darwin {

    /**
     * Returns a human readable description string for a kernel return code.
     *
     * @param kr The kernel return code to get a description for.
     * @return A string containing the description, or an unknown error message if
     * the error code is not known.
     */
    const char *kernelReturnCodeDescription(kern_return_t kr) noexcept;

    /**
     * Returns a human readable description string for a mach message return code.
     *
     * @param mr The mach message return code to get a description for.
     * @return A string containing the description, or an unknown error message if
     * the error code is not known.
     */
    const char *machMessageReturnCodeDescription(mach_msg_return_t mr) noexcept;

} // namespace darwin
} // namespace specto

#define SPECTO_LOG_KERN_RETURN(statement)                                                          \
    ({                                                                                             \
        const kern_return_t __log_kr = statement;                                                  \
        if (__log_kr != KERN_SUCCESS) {                                                            \
            SPECTO_LOG_ERROR("{} failed with kern return code: {}, description: {}", #statement,   \
                __log_kr, specto::darwin::kernelReturnCodeDescription(__log_kr));                  \
        }                                                                                          \
        __log_kr;                                                                                  \
    })

#define SPECTO_LOG_MACH_MSG_RETURN(statement)                                                      \
    ({                                                                                             \
        const mach_msg_return_t __log_mr = statement;                                              \
        if (__log_mr != MACH_MSG_SUCCESS) {                                                        \
            SPECTO_LOG_ERROR("{} failed with mach_msg return code: {}, description: {}",           \
                #statement, __log_mr, specto::darwin::machMessageReturnCodeDescription(__log_mr)); \
        }                                                                                          \
        __log_mr;                                                                                  \
    })
