#include "SentryThreadMetadataCache.hpp"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    include "SentryStackBounds.hpp"
#    include "SentryThreadHandle.hpp"

#    include <algorithm>
#    include <string>
#    include <vector>

namespace {

bool
isSentryOwnedThreadName(const std::string &name)
{
    return name.rfind("io.sentry", 0) == 0;
}

constexpr std::size_t kMaxThreadNameLength = 100;

} // namespace

namespace sentry {
namespace profiling {

    ThreadMetadata
    ThreadMetadataCache::metadataForThread(const ThreadHandle &thread)
    {
        const auto handle = thread.nativeHandle();
        const auto it = std::find_if(cache_.cbegin(), cache_.cend(),
            [handle](const ThreadHandleMetadataPair &pair) { return pair.handle == handle; });
        if (it == cache_.cend()) {
            ThreadMetadata metadata;
            metadata.threadID = ThreadHandle::tidFromNativeHandle(handle);
            metadata.priority = thread.priority();

            // If getting the priority fails (via pthread_getschedparam()), that
            // means the rest of this is probably going to fail too.
            if (metadata.priority != -1) {
                auto threadName = thread.name();
                if (isSentryOwnedThreadName(threadName)) {
                    // Don't collect backtraces for Sentry-owned threads.
                    metadata.priority = 0;
                    metadata.threadID = 0;
                    cache_.push_back({ handle, metadata });
                    return metadata;
                }
                if (threadName.size() > kMaxThreadNameLength) {
                    threadName.resize(kMaxThreadNameLength);
                }

                metadata.name = threadName;
            }

            cache_.push_back({ handle, metadata });
            return metadata;
        } else {
            return (*it).metadata;
        }
    }

} // namespace profiling
} // namespace sentry

#endif
