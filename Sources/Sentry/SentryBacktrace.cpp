#include "SentryBacktrace.hpp"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    include "SentryAsyncSafeLog.h"
#    include "SentryCompiler.h"
#    include "SentryCPU.h"
#    include "SentryMachLogging.hpp"
#    include "SentryStackBounds.hpp"
#    include "SentryStackFrame.hpp"
#    include "SentryThreadHandle.hpp"
#    include "SentryThreadMetadataCache.hpp"
#    include "SentryThreadState.hpp"
#    include "SentryTime.h"
extern "C" {
#    define restrict
/** Allow importing C99 headers that use the restrict keyword, which isn't valid in C++ */
#    include "SentryCrashMemory.h"
#    undef restrict
}
#    include <cassert>
#    include <cstring>
#    include <dispatch/dispatch.h>
#    include <pthread/stack_np.h>

using namespace sentry::profiling;
using namespace sentry::profiling::thread;

namespace {
ALWAYS_INLINE bool
isValidFrame(std::uintptr_t frame, const StackBounds &bounds)
{
    return bounds.contains(frame) && StackFrame::isAligned(frame);
}

constexpr std::size_t kMaxBacktraceDepth = 128;

} // namespace

// From https://github.com/apple-oss-distributions/libpthread/blob/d8c4e3c212553d3e0f5d76bb7d45a8acd61302dc/private/pthread/tsd_private.h#L215
#define __PTK_FRAMEWORK_SWIFT_KEY3        103

extern "C" {
// From https://github.com/apple-oss-distributions/xnu/blob/94d3b452840153a99b38a3a9659680b2a006908e/libsyscall/os/tsd.h#L149
ALWAYS_INLINE void **tsdGetBase(void) {
#if CPU(ARM)
    uintptr_t tsd;
    __asm__("mrc p15, 0, %0, c13, c0, 3\n"
                "bic %0, %0, #0x3\n" : "=r" (tsd));
#elif CPU(ARM64)
    uint64_t tsd;
    __asm__ ("mrs %0, TPIDRRO_EL0" : "=r" (tsd));
#endif
    return (void**)(uintptr_t)tsd;
}
// From https://github.com/apple-oss-distributions/libpthread/blob/d8c4e3c212553d3e0f5d76bb7d45a8acd61302dc/private/pthread/tsd_private.h#L293
ALWAYS_INLINE void *getSpecificDirect(unsigned long slot) {
#if TARGET_OS_SIMULATOR
    return pthread_getspecific(slot);
#else
#if CPU(X86) || CPU(X86_64)
    // From https://github.com/apple-oss-distributions/xnu/blob/94d3b452840153a99b38a3a9659680b2a006908e/libsyscall/os/tsd.h#L123
    void *ret;
    __asm__("mov %%gs:%1, %0" : "=r" (ret) : "m" (*(void **)(slot * sizeof(void *))));
    return ret;
#elif CPU(ARM) || CPU(ARM64)
    // From https://github.com/apple-oss-distributions/xnu/blob/94d3b452840153a99b38a3a9659680b2a006908e/libsyscall/os/tsd.h#L177
    return tsdGetBase()[slot];
#else
#error Unsupported architecture!
#endif
#endif
}
}

namespace sentry {
namespace profiling {
    // From https://github.com/apple-oss-distributions/Libc/blob/899a3b2d52d95d75e05fb286a5e64975ec3de757/gen/thread_stack_pcs.c#L44
    // Tests if a frame is part of an async extended stack.
    // If an extended frame record is needed, the prologue of the function will
    // store 3 pointers consecutively in memory:
    //    [ AsyncContext, FP | (1 << 60), LR]
    // and set the new FP to point to that second element. Bits 63:60 of that
    // in-memory FP should be considered an ABI tag of some kind, and stack
    // walkers can expect to see 3 different values in the wild:
    //    * 0b0000 if there is an old-style frame (and still most non-Swift)
    //             record with just [FP, LR].
    //    * 0b0001 if there is one of these [Ctx, FP, LR] records.
    //    * 0b1111 in current kernel code.
    std::uint32_t isAsyncFrame(std::uintptr_t frame) {
        const auto storedFp = *reinterpret_cast<std::uint64_t *>(frame);
        if ((storedFp >> 60) != 1) {
            return 0;
        }
        // The Swift runtime stores the async Task pointer in the 3rd Swift
        // private TSD.
        const auto taskAddress = reinterpret_cast<std::uintptr_t>(getSpecificDirect(__PTK_FRAMEWORK_SWIFT_KEY3));
        if (taskAddress == 0)
            return 0;
        // This offset is an ABI guarantee from the Swift runtime.
        const auto taskIDOffset = 4 * sizeof(void *) + 4;
        const auto taskIDAddress = reinterpret_cast<std::uint32_t *>(taskAddress + taskIDOffset);
        // The TaskID is guaranteed to be non-zero.
        return *taskIDAddress;
    }

    NOT_TAIL_CALLED NEVER_INLINE std::size_t
    backtrace(const ThreadHandle &targetThread, const ThreadHandle &callingThread,
        std::uintptr_t *addresses, const StackBounds &bounds, bool *reachedEndOfStackPtr,
        std::size_t maxDepth, std::size_t skip) noexcept
    {
        assert(addresses != nullptr);
        if (UNLIKELY(maxDepth == 0 || !bounds.isValid())) {
            return 0;
        }
        std::size_t depth = 0;
        MachineContext machineContext;
        if (fillThreadState(targetThread.nativeHandle(), &machineContext) != KERN_SUCCESS) {
            SENTRY_ASYNC_SAFE_LOG_ERROR("Failed to fill thread state");
            return 0;
        }
        if (LIKELY(skip == 0)) {
            addresses[depth++] = getPreviousInstructionAddress(getProgramCounter(&machineContext));
        } else {
            skip--;
        }
        if (LIKELY(depth < maxDepth)) {
            const auto lr = getLinkRegister(&machineContext);
            if (isValidFrame(lr, bounds)) {
                if (LIKELY(skip == 0)) {
                    addresses[depth++] = getPreviousInstructionAddress(lr);
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
            if (!sentrycrashmem_isMemoryReadable(reinterpret_cast<StackFrame *>(current), sizeof(StackFrame))) {
                break;
            }
            std::uintptr_t returnAddress;
#if __LP64__ || __ARM64_ARCH_8_32__
            const auto asyncTaskID = isAsyncFrame(current);
            if (asyncTaskID) {
                // From https://github.com/apple-oss-distributions/Libc/blob/899a3b2d52d95d75e05fb286a5e64975ec3de757/gen/thread_stack_pcs.c#L83
                // The async context pointer is stored right before the saved FP
                auto asyncContext = *reinterpret_cast<std::uint64_t *>(current - 8);
                std::uintptr_t resumeAddr, nextAsyncContext;
                while (depth < maxDepth) {
                    // The async context starts with 2 pointers:
                    // - the parent async context (morally equivalent to the parent
                    //   async frame frame pointer)
                    // - the resumption PC (morally equivalent to the return address)
                    // We can just use pthread_stack_frame_decode_np() because it just
                    // strips a data and a code pointer.
#if  __ARM64_ARCH_8_32__
                    // On arm64_32, the stack layout is the same (64bit pointers), but
                    // the regular pointers in the async context are still 32 bits.
                    // Given arm64_32 never has PAC, we can just read them.
                    next = *reinterpret_cast<std::uintptr_t *>(static_cast<uintptr_t>(asyncContext));
                    resumeAddr = *reinterpret_cast<std::uintptr_t *>(static_cast<uintptr_t>(asyncContext+4));
#else
                    nextAsyncContext = pthread_stack_frame_decode_np(asyncContext, &resumeAddr);
#endif
                    if (!resumeAddr) {
                        break;
                    }
                    if (LIKELY(skip == 0)) {
                        addresses[depth++] = resumeAddr;
                    } else {
                        skip--;
                    }
                    if (nextAsyncContext && StackFrame::isAligned(nextAsyncContext)) {
                        asyncContext = nextAsyncContext;
                    } else {
                        break;
                    }
                }
            }
#endif
            const auto next = pthread_stack_frame_decode_np(current, &returnAddress);
            if (LIKELY(skip == 0)) {
                addresses[depth++] = getPreviousInstructionAddress(returnAddress);
            } else {
                skip--;
            }
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

    void
    enumerateBacktracesForAllThreads(const std::function<void(const Backtrace &)> &f,
        const std::shared_ptr<ThreadMetadataCache> &cache)
    {
        const auto pair = ThreadHandle::allExcludingCurrent();
        for (const auto &thread : pair.first) {
            Backtrace bt;

            // Log an empty stack for an idle thread, we don't need to walk the stack.
            if (thread->isIdle()) {
                bt.threadMetadata.threadID = thread->tid();
                bt.threadMetadata.priority = -1;
                f(bt);
                continue;
            }

            auto metadata = cache->metadataForThread(*thread);
            if (metadata.threadID == 0) {
                continue;
            } else {
                bt.threadMetadata = std::move(metadata);
            }

            // This function calls `pthread_from_mach_thread_np`, which takes a lock,
            // so we must read the value before suspending the thread to avoid risking
            // a deadlock. See the comment below.
            const auto stackBounds = thread->stackBounds();

            // ############################################
            // DEADLOCK WARNING: It is not safe to call any functions that acquire a
            // lock between here and `thread->resume()` -- this may cause a deadlock.
            //
            // Heap allocations are unsafe, because `nanov2_malloc` takes an unfair
            // lock.
            // libsystem_kernel.dylib`__ulock_wait + 8
            // frame #1: 0x000000020dfcd9ac libsystem_platform.dylib`_os_unfair_lock_lock_slow + 172
            // frame #2: 0x00000001aeabe1d8 libsystem_malloc.dylib`nanov2_allocate + 244
            // frame #3: 0x00000001aeabe080 libsystem_malloc.dylib`nanov2_malloc + 64
            //
            // Also pay special attention to functions that may end up calling any of the
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
            const auto depth = backtrace(*thread, *pair.second, addresses, stackBounds,
                &reachedEndOfStack, kMaxBacktraceDepth, 0);

            thread->resume();

            // ############################################
            // END DEADLOCK WARNING
            // ############################################
            // Consider the backtraces only if we're able to collect the full stack
            if (reachedEndOfStack) {
                for (std::remove_const<decltype(depth)>::type i = 0; i < depth; i++) {
                    bt.addresses.push_back(addresses[i]);
                }
                f(bt);
            }
        }
    }

} // namespace profiling
} // namespace sentry

#endif
