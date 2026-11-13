#ifndef SENTRY_PROFILING_MEMORY_H
#define SENTRY_PROFILING_MEMORY_H

#include <stdbool.h>
#include <stddef.h>

/**
 * Checks whether a complete memory range is readable before the profiler dereferences it.
 *
 * The function must remain valid for the sampling session's lifetime and be safe to call while
 * other threads are suspended. It must not allocate, acquire locks, or call Objective-C or Swift.
 */
typedef bool (*SentryProfilingMemoryReader)(const void *memory, size_t byteCount);

#endif
