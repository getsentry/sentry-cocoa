// Copyright (c) Specto Inc. All rights reserved.

#include "Thread.h"

#ifdef __ANDROID__

namespace specto {
namespace thread {

#include <unistd.h>

TIDType getCurrentTID() noexcept {
    // https://android.googlesource.com/platform/bionic/+/master/libc/bionic/gettid.cpp
    return static_cast<TIDType>(gettid());
}

} // namespace thread
} // namespace specto

#elif __APPLE__

#include <mach/mach.h>

namespace specto::thread {

TIDType getCurrentTID() noexcept {
    const auto port = mach_thread_self();
    mach_port_deallocate(mach_task_self(), port);
    return static_cast<TIDType>(port);
}

} // namespace specto::thread

#endif
