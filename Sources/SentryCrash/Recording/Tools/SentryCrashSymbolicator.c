// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashSymbolicator.c
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

#include "SentryCrashSymbolicator.h"
#include "SentryCrashDynamicLinker.h"
#import <stdio.h>

/** Remove any pointer tagging from an instruction address
 * On armv7 the least significant bit of the pointer distinguishes
 * between thumb mode (2-byte instructions) and normal mode (4-byte
 * instructions). On arm64 all instructions are 4-bytes wide so the two least
 * significant bytes should always be 0. On x86_64 and i386, instructions are
 * variable length so all bits are signficant.
 */
#if defined(__arm__)
#    define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(1UL))
#elif defined(__arm64__)
#    define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(3UL))
#else
#    define DETAG_INSTRUCTION_ADDRESS(A) (A)
#endif

/** Step backwards by one instruction.
 * The backtrace of an objective-C program is expected to contain return
 * addresses not call instructions, as that is what can easily be read from
 * the stack. This is not a problem except for a few cases where the return
 * address is inside a different symbol than the call address.
 */
#define CALL_INSTRUCTION_FROM_RETURN_ADDRESS(A) (DETAG_INSTRUCTION_ADDRESS((A)) - 1)

static bool
sentrycrashsymbolicator_symbolicate_stack_entry(SentryCrashStackEntry *stackEntry, bool asyncUnsafe)
{

    if (stackEntry->address == SentryCrashSC_ASYNC_MARKER) {
        stackEntry->imageAddress = 0;
        stackEntry->imageName = 0;
        stackEntry->symbolAddress = 0;
        stackEntry->symbolName = "__sentrycrash__async_marker__";
        return true;
    }

    Dl_info symbolsBuffer;

    bool symbols_succeed = false;

    if (asyncUnsafe) {
        symbols_succeed = dladdr((void *)stackEntry->address, &symbolsBuffer) != 0;
    } else {
        symbols_succeed = sentrycrashdl_dladdr(
            CALL_INSTRUCTION_FROM_RETURN_ADDRESS(stackEntry->address), &symbolsBuffer);
    }

    if (symbols_succeed) {
        stackEntry->imageAddress = (uintptr_t)symbolsBuffer.dli_fbase;
        stackEntry->imageName = symbolsBuffer.dli_fname;
        stackEntry->symbolAddress = (uintptr_t)symbolsBuffer.dli_saddr;
        stackEntry->symbolName = symbolsBuffer.dli_sname;
        return true;
    }

    stackEntry->imageAddress = 0;
    stackEntry->imageName = 0;
    stackEntry->symbolAddress = 0;
    stackEntry->symbolName = 0;
    return false;
}

static bool
symbolicate_internal(SentryCrashStackCursor *cursor, bool asyncUnsafe)
{
    return sentrycrashsymbolicator_symbolicate_stack_entry(&cursor->stackEntry, asyncUnsafe);
}

bool
sentrycrashsymbolicator_symbolicate(SentryCrashStackCursor *cursor)
{
    return symbolicate_internal(cursor, false);
}

bool
sentrycrashsymbolicator_symbolicate_async_unsafe(SentryCrashStackCursor *cursor)
{
    return symbolicate_internal(cursor, true);
}
