#pragma once

#include "SentryProfilingConditionals.h"
#include <mach/kern_return.h>
#include <mach/message.h>

namespace sentry {

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

} // namespace sentry
