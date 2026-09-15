// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashString.h
//
//  Created by Karl Stenerud on 2012-09-15.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
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

#ifndef HDR_SentryCrashString_h
#define HDR_SentryCrashString_h

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/** Check if a memory location contains a null terminated UTF-8 string.
 *
 * @param memory The memory location to test.
 *
 * @param minLength The minimum length to be considered a valid string.
 *
 * @param maxLength The maximum length to be considered a valid string.
 */
bool sentrycrashstring_isNullTerminatedUTF8String(const void *memory, int minLength, int maxLength);

/** Extract a hex value in the form "0x123456789abcdef" from a string.
 *
 * @param string The string to search.
 *
 * @param stringLength The length of the string.
 *
 * @param result Buffer to hold the resulting value.
 *
 * @return true if the operation was successful.
 */
bool sentrycrashstring_extractHexValue(const char *string, int stringLength, uint64_t *result);

/** Formats an address as "0x" + lowercase hex into a caller-provided buffer.
 *
 * This is a replacement for snprintf in crash handlers:
 * - signal-safe: uses no stdio, malloc, locks, or thread-local state.
 * - reentrant: only stack locals; no writable globals.
 *
 * @return The number of bytes written, excluding the NUL terminator, or -1 if the buffer is too
 * small.
 */
int sentrycrashstring_addressToString(char *buffer, size_t bufferLength, uint64_t value);

/** Formats a signed integer into a caller-provided buffer.
 *
 * @return The number of bytes written, excluding the NUL terminator, or -1 if the buffer is too
 * small.
 */
int sentrycrashstring_int64ToString(char *buffer, size_t bufferLength, int64_t value);

/** Formats an unsigned integer into a caller-provided buffer.
 *
 * @return The number of bytes written, excluding the NUL terminator, or -1 if the buffer is too
 * small.
 */
int sentrycrashstring_uint64ToString(char *buffer, size_t bufferLength, uint64_t value);

/** Formats a finite double into a JSON-compatible number using six significant digits.
 *
 * This intentionally does not try to be a general dtoa replacement. It is meant for crash-handler
 * metadata where avoiding stdio/malloc/locks matters more than preserving libc's exact spelling.
 *
 * @return The number of bytes written, excluding the NUL terminator, or -1 if the buffer is too
 * small.
 */
int sentrycrashstring_doubleToString(char *buffer, size_t bufferLength, double value);

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashString_h
