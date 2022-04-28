#pragma once

#include "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    include "SentryThreadHandle.hpp"

#    include <cstdint>
#    include <memory>
#    include <string>

namespace sentry {
namespace profiling {
    struct ThreadMetadata {
        thread::TIDType threadID;
        std::string name;
        int priority;
    };

    struct QueueMetadata {
        std::uint64_t address;
        std::string label;
    };

    /**
     * Caches thread and queue metadata (name, priority, etc.) for reuse while profiling,
     * since querying that metadata every time can be expensive.
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
        
        /**
         * Returns the metadata for the queue at the specified address.
         * @param address The address of the queue to retrieve metadata from.
         * @note This function assumes that the queue address is valid. If the address
         * is invalid, the behavior is non-deterministic and will probably crash.
         * @return @c QueueMetadata for the queue at the specified address.
         */
        QueueMetadata metadataForQueue(std::uint64_t address);

        ThreadMetadataCache() = default;
        ThreadMetadataCache(const ThreadMetadataCache &) = delete;
        ThreadMetadataCache &operator=(const ThreadMetadataCache &) = delete;

    private:
        struct ThreadHandleMetadataPair {
            ThreadHandle::NativeHandle handle;
            ThreadMetadata metadata;
        };
        std::vector<const ThreadHandleMetadataPair> threadMetadataCache_;
        std::vector<const QueueMetadata> queueMetadataCache_;
    };

} // namespace profiling
} // namespace sentry

#endif
