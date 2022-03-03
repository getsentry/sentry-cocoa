#include "SentryThreadMetadataCache.h"

#include "SentryThreadHandle.h"
#include "SentryStackBounds.h"
#include "SentryProtoPolyfills.h"

#include <algorithm>
#include <string>
#include <vector>

namespace {

bool isSpectoOwnedThreadName(const std::string &name) {
    return name.rfind("dev.specto", 0) == 0;
}

constexpr std::size_t kMaxThreadQueueNameLength = 100;

} // namespace

namespace sentry {
namespace profiling {

class ThreadMetadataCache::Impl {
public:
    SentryProfilingEntry *entryForThread(const ThreadHandle &thread) {
        const auto handle = thread.nativeHandle();
        const auto it =
          std::find_if(cache_.cbegin(), cache_.cend(), [handle](const ThreadHandleEntryPair &pair) {
              return pair.handle == handle;
          });
        if (it == cache_.cend()) {
            auto entry = [[SentryProfilingEntry alloc] init];
            entry->tid = ThreadHandle::tidFromNativeHandle(handle);

            const auto backtrace = entry->backtrace;
            const auto priority = thread.priority();
            backtrace->priority = priority;

            // If getting the priority fails (via pthread_getschedparam()), that
            // means the rest of this is probably going to fail too.
            if (priority != -1) {
                auto threadName = thread.name();
                auto dispatchQueueLabel = thread.dispatchQueueLabel();
                if (isSpectoOwnedThreadName(threadName)
                    || isSpectoOwnedThreadName(dispatchQueueLabel)) {
                    // Don't collect backtraces for Specto-owned threads.
                    cache_.push_back({handle, nullptr});
                    return nullptr;
                }
                if (threadName.size() > kMaxThreadQueueNameLength) {
                    threadName.resize(kMaxThreadQueueNameLength);
                }
                if (dispatchQueueLabel.size() > kMaxThreadQueueNameLength) {
                    dispatchQueueLabel.resize(kMaxThreadQueueNameLength);
                }

                backtrace->threadName = [NSString stringWithUTF8String:threadName.c_str()];
                backtrace->queueName = [NSString stringWithUTF8String:dispatchQueueLabel.c_str()];;
            }

            cache_.push_back({handle, entry});
            return entry;
        } else {
            return (*it).entry;
        }
    }

private:
    struct ThreadHandleEntryPair {
        ThreadHandle::NativeHandle handle;
        SentryProfilingEntry *entry;
    };
    std::vector<const ThreadHandleEntryPair> cache_;
};

ThreadMetadataCache::ThreadMetadataCache() : impl_(spimpl::make_unique_impl<Impl>()) { }

SentryProfilingEntry *ThreadMetadataCache::entryForThread(const ThreadHandle &thread) {
    return impl_->entryForThread(thread);
}

} // namespace profiling
} // namespace sentry
