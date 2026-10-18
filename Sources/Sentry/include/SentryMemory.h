#ifndef SENTRY_MEMORY_H
#define SENTRY_MEMORY_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Returns whether the complete memory range can be read by the current process. */
bool sentryMemoryIsReadable(const void *memory, size_t byteCount);

#ifdef __cplusplus
}
#endif

#endif
