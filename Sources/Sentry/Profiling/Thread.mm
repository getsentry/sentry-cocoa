#include "Thread.h"

#include <mach/mach.h>

namespace specto {
namespace thread {

TIDType getCurrentTID() noexcept {
    const auto port = mach_thread_self();
    mach_port_deallocate(mach_task_self(), port);
    return static_cast<TIDType>(port);
}

} // namespace thread
} // namespace specto
