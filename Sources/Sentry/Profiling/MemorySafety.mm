// From https://github.com/kstenerud/KSCrash/blob/master/Source/KSCrash/Recording/Tools/KSMemory.c
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

#include <mach/mach.h>

namespace specto {
namespace darwin {
namespace {
inline int
  copySafely(const void *__restrict const src, void *__restrict const dst, const int byteCount) {
    vm_size_t bytesCopied = 0;
    kern_return_t result = vm_read_overwrite(mach_task_self(),
                                             reinterpret_cast<vm_address_t>(src),
                                             static_cast<vm_size_t>(byteCount),
                                             reinterpret_cast<vm_address_t>(dst),
                                             &bytesCopied);
    if (result != KERN_SUCCESS) {
        return 0;
    }
    return static_cast<int>(bytesCopied);
}

char g_memoryTestBuffer[10240];
} // namespace

bool isMemoryReadable(const void *const memory, const int byteCount) {
    const int testBufferSize = sizeof(g_memoryTestBuffer);
    auto bytesRemaining = byteCount;

    while (bytesRemaining > 0) {
        const auto bytesToCopy = bytesRemaining > testBufferSize ? testBufferSize : bytesRemaining;
        if (copySafely(memory, g_memoryTestBuffer, bytesToCopy) != bytesToCopy) {
            break;
        }
        bytesRemaining -= bytesToCopy;
    }
    return bytesRemaining == 0;
}
} // namespace darwin
} // namespace specto
