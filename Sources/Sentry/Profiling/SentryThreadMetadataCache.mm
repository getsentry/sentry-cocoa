#include "SentryThreadMetadataCache.h"

#include "SentryThreadHandle.h"
#include "SentryStackBounds.h"
#include "SentryProtoPolyfills.h"

#include <algorithm>
#include <string>
#include <vector>

namespace {

bool isSentryOwnedThreadName(const std::string &name) {
    return name.rfind("io.sentry", 0) == 0;
}

constexpr std::size_t kMaxThreadNameLength = 100;

} // namespace

namespace sentry {
namespace profiling {

class ThreadMetadataCache::Impl {
public:
    std::optional<ThreadMetadata> metadataForThread(const ThreadHandle &thread) {
        const auto handle = thread.nativeHandle();
        const auto it =
          std::find_if(cache_.cbegin(), cache_.cend(), [handle](const ThreadHandleMetadataPair &pair) {
              return pair.handle == handle;
          });
        if (it == cache_.cend()) {
            ThreadMetadata metadata;
            metadata.tid = ThreadHandle::tidFromNativeHandle(handle);
            metadata.priority = thread.priority();

            // If getting the priority fails (via pthread_getschedparam()), that
            // means the rest of this is probably going to fail too.
            if (metadata.priority != -1) {
                auto threadName = thread.name();
                if (isSentryOwnedThreadName(threadName)) {
                    // Don't collect backtraces for Sentry-owned threads.
                    cache_.push_back({handle, std::nullopt});
                    return std::nullopt;
                }
                if (threadName.size() > kMaxThreadNameLength) {
                    threadName.resize(kMaxThreadNameLength);
                }

                metadata.name = threadName;
            }

            cache_.push_back({handle, metadata});
            return metadata;
        } else {
            return (*it).metadata;
        }
    }

private:
    struct ThreadHandleMetadataPair {
        ThreadHandle::NativeHandle handle;
        std::optional<ThreadMetadata> metadata;
    };
    std::vector<const ThreadHandleMetadataPair> cache_;
};

ThreadMetadataCache::ThreadMetadataCache() : impl_(spimpl::make_unique_impl<Impl>()) { }

std::optional<ThreadMetadata> ThreadMetadataCache::metadataForThread(const ThreadHandle &thread) {
    return impl_->metadataForThread(thread);
}

} // namespace profiling
} // namespace sentry
