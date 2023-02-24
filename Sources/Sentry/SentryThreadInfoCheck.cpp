#include "SentryThreadInfoCheck.hpp"
#include <cstdint>
#include <dispatch/dispatch.h>

namespace {
static char g_memoryTestBuffer[10240];

inline int
_copySafely(const void *const src, void *const dst, const int byteCount)
{
    vm_size_t bytesCopied = 0;
    kern_return_t result = vm_read_overwrite(
        mach_task_self(), (vm_address_t)src, (vm_size_t)byteCount, (vm_address_t)dst, &bytesCopied);
    if (result != KERN_SUCCESS) {
        return 0;
    }
    return (int)bytesCopied;
}

inline bool
_isMemoryReadable(const void *const memory, const int byteCount)
{
    const int testBufferSize = sizeof(g_memoryTestBuffer);
    int bytesRemaining = byteCount;

    while (bytesRemaining > 0) {
        int bytesToCopy = bytesRemaining > testBufferSize ? testBufferSize : bytesRemaining;
        if (_copySafely(memory, g_memoryTestBuffer, bytesToCopy) != bytesToCopy) {
            break;
        }
        bytesRemaining -= bytesToCopy;
    }
    return bytesRemaining == 0;
}
} // namespace

bool
isValidQueuePointer(thread_identifier_info_t idInfo)
{
    const auto queuePtr = reinterpret_cast<dispatch_queue_t *>(idInfo->dispatch_qaddr);
    return queuePtr != nullptr && _isMemoryReadable(queuePtr, sizeof(*queuePtr))
        && idInfo->thread_handle != 0 && *queuePtr != nullptr;
}

bool
isValidThreadInfo(thread_identifier_info_t idInfo)
{
    return _isMemoryReadable(idInfo, sizeof(*idInfo));
}
