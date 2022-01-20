// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#ifndef __APPLE__
#error Non-Apple platforms are not supported!
#endif

#include "cpp/stack/src/StackBounds.h"
#include "cpp/thread/src/Thread.h"

#include <chrono>
#include <mach/mach.h>
#include <memory>
#include <pthread.h>
#include <string>
#include <sys/qos.h>
#include <type_traits>
#include <utility>
#include <vector>

/**
 * Threading helpers for Darwin-based platforms.
 */
namespace specto {
namespace darwin {

struct QoS {
    /**
     * - QOS_CLASS_USER_INTERACTIVE
     * - QOS_CLASS_USER_INITIATED
     * - QOS_CLASS_DEFAULT
     * - QOS_CLASS_UTILITY
     * - QOS_CLASS_BACKGROUND
     * - QOS_CLASS_UNSPECIFIED
     */
    qos_class_t qosClass = QOS_CLASS_UNSPECIFIED;
    /** A relative priority offset within the QOS class. */
    int relativePriority = 0;
};

enum class ThreadRunState { Undefined, Running, Stopped, Waiting, Uninterruptible, Halted };

struct ThreadCPUInfo {
    /** User run time in microseconds. */
    std::chrono::microseconds userTimeMicros;
    /** System run time in microseconds. */
    std::chrono::microseconds systemTimeMicros;
    /** CPU usage percentage from 0.0 to 1.0. */
    float usagePercent;
    /** Current run state of the thread. */
    ThreadRunState runState;
    /** Whether the thread is idle or not. */
    bool idle;
};

class ThreadHandle {
public:
    using NativeHandle = thread_t;

    static_assert(std::is_fundamental<NativeHandle>::value,
                  "NativeHandle must be a fundamental type");

    /**
     * Constructs a \ref ThreadHandle using a native handle type.
     * @param handle The native thread handle.
     * @return An instance of \ref ThreadHandle
     */
    explicit ThreadHandle(NativeHandle handle) noexcept;

    /**
     * @return A handle to the currently executing thread, which is acquired
     * in a non async-signal-safe manner.
     */
    static std::unique_ptr<ThreadHandle> current() noexcept;

    /**
     * @return A vector of handles for all of the threads in the current process.
     */
    static std::vector<std::unique_ptr<ThreadHandle>> all() noexcept;

    /**
     * @return A pair, where the first element is a vector of handles for all of
     * the threads in the current process, excluding the current thread (the
     * thread that this function is being called on), and the second element
     * is a handle to the current thread.
     */
    static std::pair<std::vector<std::unique_ptr<ThreadHandle>>, std::unique_ptr<ThreadHandle>>
      allExcludingCurrent() noexcept;

    /**
     * @param handle The native handle to get the TID from.
     * @return The TID of the thread that the native handle represents.
     */
    static thread::TIDType tidFromNativeHandle(NativeHandle handle);

    /**
     * @return The underlying native thread handle.
     */
    NativeHandle nativeHandle() const noexcept;

    /**
     * @return The ID of the thread.
     */
    thread::TIDType tid() const noexcept;

    /**
     * @return The name of the thread, or an empty string if the thread doesn't
     * have a name, or if there was failure in acquiring the name.
     *
     * @warning This function is not async-signal safe!
     */
    std::string name() const noexcept;

    /**
     * @return The queue label, or an empty string if retrieving the label failed or
     * the thread is not associated with a dispatch queue.
     *
     * @warning This function is not async-signal safe!
     */
    std::string dispatchQueueLabel() const noexcept;

    /**
     * @return The priority of the specified thread, or -1 if the thread priority
     * could not be successfully determined.
     *
     * @warning This function is not async-signal safe!
     */
    int priority() const noexcept;

    /**
     * @return Darwin QoS attributes associated with the thread.
     *
     * @warning This function is not async-signal safe!
     */
    QoS qos() const noexcept;

    /**
     * @return CPU usage information for the thread.
     */
    ThreadCPUInfo cpuInfo() const noexcept;

    /**
     * @return Whether the thread is currently idle.
     */
    bool isIdle() const noexcept;

    /**
     * @return The bounds of the thread's stack (start, end)
     *
     * @warning This function is not async-signal safe!
     */
    StackBounds stackBounds() const noexcept;

    /**
     * Suspends the thread, incrementing the suspend counter.
     * @return Whether the thread was successfully suspended.
     */
    bool suspend() const noexcept;

    /**
     * Resumes the thread, decrementing the suspend counter.
     * @return Whether the thread was successfully resumed.
     */
    bool resume() const noexcept;

    bool operator==(const ThreadHandle &other) const;

    ~ThreadHandle();
    ThreadHandle(const ThreadHandle &) = delete;
    ThreadHandle &operator=(const ThreadHandle &) = delete;

private:
    NativeHandle handle_;
    bool isOwnedPort_;
    mutable pthread_t pthreadHandle_;

    ThreadHandle(NativeHandle handle, bool isOwnedPort) noexcept;
    pthread_t pthreadHandle() const noexcept;
};

} // namespace darwin
} // namespace specto
