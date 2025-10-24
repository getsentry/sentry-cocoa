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

// Apple's `libpthread` has a hard limit of 64 characters for thread names.
// See
// https://github.com/apple-oss-distributions/libpthread/blob/42d026df5b07825070f60134b980a1ec2552dfee/src/pthread.c#L1178
constexpr std::size_t kMaxThreadNameLength = 64;

} // namespace

namespace sentry {
namespace profiling {

    ThreadMetadata
    ThreadMetadataCache::metadataForThread(const ThreadHandle &thread)
    {
        const auto handle = thread.nativeHandle();
        const auto it = std::find_if(threadMetadataCache_.cbegin(), threadMetadataCache_.cend(),
            [handle](const ThreadHandleMetadataPair &pair) { return pair.handle == handle; });
        if (it == threadMetadataCache_.cend()) {
            ThreadMetadata metadata;
            metadata.threadID = ThreadHandle::tidFromNativeHandle(handle);
            metadata.priority = thread.priority();

            // If getting the priority fails (via pthread_getschedparam()), that
            // means the rest of this is probably going to fail too. We also don't
            // want to cache this result.
            if (metadata.priority == -1) {
                return metadata;
            }

            auto threadName = thread.name();
            if (isSentryOwnedThreadName(threadName)) {
                // Don't collect backtraces for Sentry-owned threads.
                metadata.priority = 0;
                metadata.threadID = 0;
                threadMetadataCache_.push_back({ handle, metadata });
                return metadata;
            }
            if (threadName.size() > kMaxThreadNameLength) {
                threadName.resize(kMaxThreadNameLength);
            }

            metadata.name = threadName;
            threadMetadataCache_.push_back({ handle, metadata });
            return metadata;
        } else {
            return (*it).metadata;
        }
    }
} // namespace profiling
} // namespace sentry

#endif
