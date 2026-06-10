//  SentryCrashStackCursor.h
//
//  Copyright (c) 2016 Karl Stenerud. All rights reserved.
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
// Compatibility shim — forwards to upstream KSCrash.
//
// SentryCrashStackEntry is aliased to the stackEntry inner struct of KSStackCursor.
//
// Sentry-specific additions kept here:
//   SentryCrashSC_ASYNC_MARKER — special frame marker for async stack stitching.

#ifndef SentryCrashStackCursor_h
#define SentryCrashStackCursor_h

#include "KSStackCursor.h"

#ifdef __cplusplus
extern "C" {
#endif

// SentryCrashStackEntry is the anonymous struct type of KSStackCursor.stackEntry.
// We can't typedef it directly, so we replicate the fields as a named type.
// Code that accesses cursor.stackEntry.* works directly via KSStackCursor.
// Code that takes SentryCrashStackEntry as a value type needs this typedef.
typedef struct {
    uintptr_t address;
    const char *imageName;
    uintptr_t imageAddress;
    const char *symbolName;
    uintptr_t symbolAddress;
} SentryCrashStackEntry;

/** A special marker frame to denote a chained async stacktrace (Sentry-specific). */
static uint64_t SentryCrashSC_ASYNC_MARKER = UINTPTR_MAX - 1234;

#ifdef __cplusplus
}
#endif

#endif // SentryCrashStackCursor_h
