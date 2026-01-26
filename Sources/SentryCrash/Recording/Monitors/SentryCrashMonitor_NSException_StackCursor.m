// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMonitor_NSException_StackCursor.m
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "SentryCrashMonitor_NSException_StackCursor.h"
#import "SentryCrashStackCursor_Backtrace.h"
#import "SentryCrashStackCursor_SelfThread.h"

#import "SentryLogC.h"

/** Initialize stack cursor from exception.
 * If the exception has callStackReturnAddresses, use them.
 * Otherwise, capture the current thread's stack trace.
 *
 * @param cursor The stack cursor to initialize.
 * @param exception The exception to extract stack trace from.
 * @return Pointer to allocated callstack array if exception had addresses, NULL otherwise.
 *         Caller is responsible for freeing this pointer after the cursor is no longer needed.
 */
uintptr_t *
sentrycrashcm_nsexception_initStackCursor(SentryCrashStackCursor *cursor, NSException *exception)
{
    NSArray *addresses = [exception callStackReturnAddresses];
    NSUInteger numFrames = addresses.count;

    if (numFrames == 0) {
        // Happens when NSApplication.shared.reportException is called without raising the
        // exception.
        SENTRY_LOG_DEBUG(
            @"callStackReturnAddresses is empty, capturing current thread stack trace");
        sentrycrashsc_initSelfThread(cursor, 0);
        return NULL;
    } else {
        uintptr_t *callstack = malloc(numFrames * sizeof(*callstack));
        assert(callstack != NULL);
        for (NSUInteger i = 0; i < numFrames; i++) {
            callstack[i] = (uintptr_t)[addresses[i] unsignedLongLongValue];
        }
        sentrycrashsc_initWithBacktrace(cursor, callstack, (int)numFrames, 0);
        return callstack;
    }
}
