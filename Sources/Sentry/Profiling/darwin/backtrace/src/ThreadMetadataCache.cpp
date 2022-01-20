// Copyright (c) Specto Inc. All rights reserved.

#include "ThreadMetadataCache.h"

#include "cpp/darwin/thread/src/ThreadHandle.h"
#include "cpp/stack/src/StackBounds.h"
#include "spectoproto/backtrace/backtrace_generated.pb.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <algorithm>
#include <string>
#include <vector>

using namespace specto;

namespace {
// QoS data collection is disabled, see the comments below for the reasoning.
//
// proto::QoS_Class getProtoQoSClass(qos_class_t qosClass) {
//     switch (qosClass) {
//         case QOS_CLASS_USER_INTERACTIVE:
//             return proto::QoS_Class_USER_INTERACTIVE;
//         case QOS_CLASS_USER_INITIATED:
//             return proto::QoS_Class_USER_INITIATED;
//         case QOS_CLASS_DEFAULT:
//             return proto::QoS_Class_DEFAULT;
//         case QOS_CLASS_UTILITY:
//             return proto::QoS_Class_UTILITY;
//         case QOS_CLASS_BACKGROUND:
//             return proto::QoS_Class_BACKGROUND;
//         case QOS_CLASS_UNSPECIFIED:
//             [[fallthrough]];
//         default:
//             return proto::QoS_Class_UNSPECIFIED;
//     }
// }

bool isSpectoOwnedThreadName(const std::string &name) {
    return name.rfind("dev.specto", 0) == 0;
}

constexpr std::size_t kMaxThreadQueueNameLength = 100;

} // namespace

namespace specto::darwin {

class ThreadMetadataCache::Impl {
public:
    std::shared_ptr<proto::Entry> entryForThread(const ThreadHandle &thread) {
        const auto handle = thread.nativeHandle();
        const auto it =
          std::find_if(cache_.cbegin(), cache_.cend(), [handle](const ThreadHandleEntryPair &pair) {
              return pair.handle == handle;
          });
        if (it == cache_.cend()) {
            auto entry = std::make_shared<proto::Entry>();
            entry->set_tid(ThreadHandle::tidFromNativeHandle(handle));
            entry->set_type(proto::Entry_Type_BACKTRACE);

            const auto backtrace = entry->mutable_backtrace();
            const auto priority = thread.priority();
            backtrace->set_priority(priority);

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

                backtrace->set_thread_name(std::move(threadName));
                backtrace->set_queue_name(std::move(dispatchQueueLabel));

                // QoS collection is disabled because `pthread_get_qos_class_np` is a crashy API.
                // See reports:
                // * https://developer.apple.com/forums/thread/123934
                // * https://stackoverflow.com/questions/57847960/app-is-getting-crashed-on-app-launch-in-ios-13-beta-version
                //
                // We are currently not using the QoS information for any product features, so it
                // is safer to disable this for the time being (or figure out which OS versions we
                // can enable it on).
                //
                // const auto qos = thread.qos();
                // backtrace->mutable_qos()->set_class_(getProtoQoSClass(qos.qosClass));
                // backtrace->mutable_qos()->set_relative_priority(qos.relativePriority);
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
        std::shared_ptr<proto::Entry> entry;
    };
    std::vector<const ThreadHandleEntryPair> cache_;
};

ThreadMetadataCache::ThreadMetadataCache() : impl_(spimpl::make_unique_impl<Impl>()) { }

std::shared_ptr<proto::Entry> ThreadMetadataCache::entryForThread(const ThreadHandle &thread) {
    return impl_->entryForThread(thread);
}

} // namespace specto::darwin
