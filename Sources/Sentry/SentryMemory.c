#include "SentryMemory.h"

#include <limits.h>

#include <KSMemory.h>

bool
sentryMemoryIsReadable(const void *memory, size_t byteCount)
{
    if (byteCount > INT_MAX) {
        return false;
    }
    return ksmem_isMemoryReadable(memory, (int)byteCount);
}
