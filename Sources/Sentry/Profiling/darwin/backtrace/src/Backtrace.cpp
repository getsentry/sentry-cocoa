// Copyright (c) Specto Inc. All rights reserved.

#include "Backtrace.h"

#include "ThreadMetadataCache.h"
#include "Log.h"
#include "ThreadHandle.h"
#include "ThreadState.h"
#include "Compiler.h"
#include "StackBounds.h"
#include "StackFrame.h"
#include "Time.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <cassert>

#if __has_include(<ptrauth.h>)
#include <ptrauth.h>
#else
#define ptrauth_strip(__value, __key) __value
#endif

using namespace specto;
using namespace specto::darwin;
using namespace specto::darwin::thread;

#define LIKELY(x) __builtin_expect(!!(x), 1)
#define UNLIKELY(x) __builtin_expect(!!(x), 0)

namespace {
ALWAYS_INLINE bool isValidFrame(std::uintptr_t frame, const specto::StackBounds &bounds) {
    return bounds.contains(frame) && specto::StackFrame::isAligned(frame);
}

ALWAYS_INLINE std::uintptr_t stripPtrAuthentication(std::uintptr_t retAddr) {
    // https://github.com/apple/darwin-xnu/blob/8f02f2a044b9bb1ad951987ef5bab20ec9486310/osfmk/kern/backtrace.c#L120
    return reinterpret_cast<std::uintptr_t>(
      ptrauth_strip(reinterpret_cast<void *>(retAddr), ptrauth_key_return_address));
}

constexpr std::size_t kMaxBacktraceDepth = 128;

} // namespace

namespace specto::darwin {
NOT_TAIL_CALLED NEVER_INLINE std::size_t backtrace(const ThreadHandle &targetThread,
                                                   const ThreadHandle &callingThread,
                                                   std::uintptr_t *addresses,
                                                   const StackBounds &bounds,
                                                   bool *reachedEndOfStackPtr,
                                                   std::size_t maxDepth,
                                                   std::size_t skip) noexcept {
    assert(addresses != nullptr);
    if (UNLIKELY(maxDepth == 0 || !bounds.isValid())) {
        return 0;
    }
    std::size_t depth = 0;
    MachineContext machineContext;
    if (fillThreadState(targetThread.nativeHandle(), &machineContext) != KERN_SUCCESS) {
        SPECTO_LOG_ASYNC_SAFE_ERROR("Failed to fill thread state");
        return 0;
    }
    if (LIKELY(skip == 0)) {
        addresses[depth++] = getProgramCounter(&machineContext);
    } else {
        skip--;
    }
    if (LIKELY(depth < maxDepth)) {
        const auto lr = getLinkRegister(&machineContext);
        if (isValidFrame(lr, bounds)) {
            if (LIKELY(skip == 0)) {
                addresses[depth++] = stripPtrAuthentication(lr);
            } else {
                skip--;
            }
        }
    }
    std::uintptr_t current;
    if (UNLIKELY(callingThread == targetThread)) {
        current = reinterpret_cast<std::uintptr_t>(__builtin_frame_address(0));
    } else {
        current = getFrameAddress(&machineContext);
    }
    // Even if this bounds check passes, the frame pointer address could still be invalid if the
    // thread was suspended in an inconsistent state. The best we can do is to detect these
    // situations at symbolication time on the server and filter them out -- there's not an easy
    // architecture agnostic way to detect this on the client without a more complicated stack
    // unwinding implementation (e.g. DWARF)
    if (UNLIKELY(!isValidFrame(current, bounds))) {
        return 0;
    }
    bool reachedEndOfStack = false;
    while (depth < maxDepth) {
        const auto frame = reinterpret_cast<StackFrame *>(current);
        if (LIKELY(skip == 0)) {
            addresses[depth++] = stripPtrAuthentication(frame->returnAddress);
        } else {
            skip--;
        }
        const auto next = reinterpret_cast<std::uintptr_t>(frame->next);
        if (next > current && isValidFrame(next, bounds)) {
            current = next;
        } else {
            reachedEndOfStack = true;
            break;
        }
    }
    if (LIKELY(reachedEndOfStackPtr != nullptr)) {
        *reachedEndOfStackPtr = reachedEndOfStack;
    }
    return depth;
}

void enumerateBacktracesForAllThreads(const std::function<void(std::shared_ptr<proto::Entry>)> &f,
                                      const std::shared_ptr<ThreadMetadataCache> &cache,
                                      bool measureCost) {
    const auto pair = ThreadHandle::allExcludingCurrent();
    for (const auto &thread : pair.first) {
        if (thread->isIdle()) {
            continue;
        }
        auto entry = cache->entryForThread(*thread);
        if (entry == nullptr) {
            continue;
        }
        // This function calls `pthread_from_mach_thread_np`, which takes a lock,
        // so we must read the value before suspending the thread to avoid risking
        // a deadlock. See the comment below.
        const auto stackBounds = thread->stackBounds();

        // This one is probably safe to call while the thread is suspended, but
        // being conservative here in case the platform time functions take any
        // locks that we're not aware of.
        const auto startTimeNs = time::getUptimeNs();

        // ############################################
        // DEADLOCK WARNING: It is not safe to call any functions that acquire a
        // lock between here and `thread->resume()` -- this may cause a deadlock.
        // Pay special attention to functions that may end up calling any of the
        // pthread_*_np functions, which typically take a lock used by other
        // OS APIs like GCD. You can see the full list of functions that take the
        // lock by going here and searching for `_pthread_list_lock:
        // https://github.com/apple/darwin-libpthread/blob/master/src/pthread.c
        // ############################################
        if (!thread->suspend()) {
            continue;
        }

        bool reachedEndOfStack = false;
        std::uintptr_t addresses[kMaxBacktraceDepth];
        const auto depth = specto::darwin::backtrace(
          *thread, *pair.second, addresses, stackBounds, &reachedEndOfStack, kMaxBacktraceDepth, 0);

        thread->resume();
        // ############################################
        // END DEADLOCK WARNING
        // ############################################

        // Consider the backtraces only if we're able to collect the full stack
        if (reachedEndOfStack) {
            const auto backtrace = entry->mutable_backtrace();
            backtrace->mutable_addresses()->Clear();
            backtrace->mutable_addresses()->Reserve(depth);
            for (std::remove_const<decltype(depth)>::type i = 0; i < depth; i++) {
                backtrace->add_addresses(addresses[i]);
            }
            entry->set_elapsed_relative_to_start_date_ns(startTimeNs);
            if (measureCost) {
                entry->set_cost_ns(time::getDurationNs(startTimeNs).count());
            }
            f(std::move(entry));
        }
    }
}

} // namespace specto::darwin
