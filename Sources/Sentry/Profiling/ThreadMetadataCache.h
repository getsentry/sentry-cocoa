#pragma once

#include "ThreadHandle.h"
#include "spimpl.h"

#include <memory>

#import <Foundation/Foundation.h>

@class SentryProfilingEntry;

namespace sentry {
namespace profiling {

    /**
     * Caches thread metadata (name, priority, etc.) and prepopulates a recycled `proto::Entry`
     * object with that data. A new `proto::Entry` and corresponding `proto::Backtrace` object are
     * created for each thread, if one does not already exist.
     *
     * @note This class is not thread-safe.
     */
    class ThreadMetadataCache {
    public:
        /**
         * Returns an entry that is pre-populated with the metadata for the thread with the
         * specified thread. If called multiple times for the same thread, this returns the same
         * pointer.
         * @param thread The thread to retrieve metadata from.
         * @return A @c SentryProfilingEntry with the backtrace payload fields pre-populated with
         * the thread metadata upon success, or @c nil in cases where a backtrace should not be
         * collected for the specified thread.
         */
        SentryProfilingEntry *entryForThread(const ThreadHandle &thread);

        ThreadMetadataCache();
        ThreadMetadataCache(const ThreadMetadataCache &) = delete;
        ThreadMetadataCache &operator=(const ThreadMetadataCache &) = delete;

    private:
        class Impl;
        spimpl::unique_impl_ptr<Impl> impl_;
    };
} // namespace profiling
} // namespace sentry
