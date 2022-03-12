#pragma once

#include "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    include "SentryThreadHandle.hpp"

#    include <memory>
#    include <string>

namespace sentry {
namespace profiling {
    struct ThreadMetadata {
        thread::TIDType threadID;
        std::string name;
        int priority;
    };

    /**
     * Caches thread metadata (name, priority, etc.) for reuse while profiling, since querying that
     * metadata from the thread every time can be expensive.
     *
     * @note This class is not thread-safe.
     */
    class ThreadMetadataCache {
    public:
        /**
         * Returns the metadata for the thread represented by the specified handle.
         * @param thread The thread handle to retrieve metadata from.
         * @return @c ThreadMetadata with a non-zero threadID upon success, or a zero
         * threadID upon failure, which means that metadata cannot be collected
         * for this thread.
         */
        ThreadMetadata metadataForThread(const ThreadHandle &thread);

        ThreadMetadataCache() = default;
        ThreadMetadataCache(const ThreadMetadataCache &) = delete;
        ThreadMetadataCache &operator=(const ThreadMetadataCache &) = delete;

    private:
        struct ThreadHandleMetadataPair {
            ThreadHandle::NativeHandle handle;
            ThreadMetadata metadata;
        };
        std::vector<const ThreadHandleMetadataPair> cache_;
    };

} // namespace profiling
} // namespace sentry

#endif
