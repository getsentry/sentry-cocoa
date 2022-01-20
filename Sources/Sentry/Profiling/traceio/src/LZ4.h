// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "Log.h"
#include "external/com_github_lz4_lz4/lib/lz4frame.h"

// Returns whether the error code is an LZ4 error. If it is an error, it
// will be logged.
#define CHECK_LZ4_ERROR(code)                                \
    ({                                                       \
        bool __is_lz4_error = false;                         \
        if (LZ4F_isError(code)) {                            \
            const auto __err_name = LZ4F_getErrorName(code); \
            SPECTO_LOG_ERROR("LZ4 error: {}", __err_name);   \
            __is_lz4_error = true;                           \
        }                                                    \
        __is_lz4_error;                                      \
    })
