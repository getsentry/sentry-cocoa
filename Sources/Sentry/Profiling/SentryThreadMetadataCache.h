#pragma once

#include "SentryThreadHandle.h"
#include "spimpl.h"

#include <memory>
#include <optional>
#include <string>

namespace sentry {
namespace profiling {
struct ThreadMetadata {
    thread::TIDType tid;
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
     * @return @c ThreadMetadata upon success, or @c std::nullopt if the metadata could not be
     * queried. A failure in this case might mean that the thread is no longer alive.
     */
    std::optional<ThreadMetadata> metadataForThread(const ThreadHandle &thread);

    ThreadMetadataCache();
    ThreadMetadataCache(const ThreadMetadataCache &) = delete;
    ThreadMetadataCache &operator=(const ThreadMetadataCache &) = delete;

private:
    class Impl;
    spimpl::unique_impl_ptr<Impl> impl_;
};

} // namespace profiling
} // namespace sentry
