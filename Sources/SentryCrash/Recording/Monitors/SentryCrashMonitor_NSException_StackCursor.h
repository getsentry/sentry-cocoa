// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMonitor_NSException_StackCursor.h
//
//  Created by Karl Stenerud on 2012-01-28.
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
// FITNESS FOR A PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#ifndef HDR_SentryCrashMonitor_NSException_StackCursor_h
#define HDR_SentryCrashMonitor_NSException_StackCursor_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

@class NSException;
struct SentryCrashStackCursor;
typedef struct SentryCrashStackCursor SentryCrashStackCursor;

/** Initialize stack cursor from exception.
 * If the exception has callStackReturnAddresses, use them.
 * Otherwise, capture the current thread's stack trace.
 *
 * @param cursor The stack cursor to initialize.
 * @param exception The exception to extract stack trace from.
 * @return Pointer to allocated callstack array if exception had addresses, NULL otherwise.
 *         Caller is responsible for freeing this pointer after the cursor is no longer needed.
 */
uintptr_t *sentrycrashcm_nsexception_initStackCursor(
    SentryCrashStackCursor *cursor, NSException *exception);

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashMonitor_NSException_StackCursor_h
