#include "SentryMemory.h"

#include <limits.h>

#if SDK_V10
#    include <KSMemory.h>
#else
#    include "SentryCrashMemory.h"
#endif

bool
sentryMemoryIsReadable(const void *memory, size_t byteCount)
{
    if (byteCount > INT_MAX) {
        return false;
    }
#if SDK_V10
    return ksmem_isMemoryReadable(memory, (int)byteCount);
#else
    return sentrycrashmem_isMemoryReadable(memory, (int)byteCount);
#endif
}
