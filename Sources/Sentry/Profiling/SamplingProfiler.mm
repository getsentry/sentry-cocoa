#include "SamplingProfiler.h"

#include "Backtrace.h"
#include "ThreadMetadataCache.h"
#include "DarwinLog.h"
#include "ThreadPriority.h"
#include "Exception.h"

#include <chrono>
#include <mach/clock.h>
#include <mach/clock_reply.h>
#include <mach/clock_types.h>
#include <pthread.h>

namespace specto {
namespace darwin {
namespace {
void samplingThreadCleanup(void* buf) {
    free(buf);
}

void* samplingThreadMain(mach_port_t port,
                         clock_serv_t clock,
                         mach_timespec_t delaySpec,
                         std::shared_ptr<ThreadMetadataCache> cache,
                         std::function<void(SentryProfilingEntry*)> callback,
                         bool measureCost,
                         std::atomic_uint64_t& numSamples,
                         std::function<void()> onThreadStart) {
    SPECTO_LOG_ERROR_RETURN(pthread_setname_np("dev.specto.SamplingProfiler"));
    const int maxSize = 512;
    const auto bufRequest = reinterpret_cast<mig_reply_error_t*>(malloc(maxSize));
    if (onThreadStart) {
        onThreadStart();
    }
    pthread_cleanup_push(samplingThreadCleanup, bufRequest);
    while (true) {
        pthread_testcancel();
        if (SPECTO_LOG_MACH_MSG_RETURN(mach_msg(&bufRequest->Head,
                                                MACH_RCV_MSG,
                                                0,
                                                maxSize,
                                                port,
                                                MACH_MSG_TIMEOUT_NONE,
                                                MACH_PORT_NULL))
            != MACH_MSG_SUCCESS) {
            break;
        }
        if (SPECTO_LOG_KERN_RETURN(clock_alarm(clock, TIME_RELATIVE, delaySpec, port))
            != KERN_SUCCESS) {
            break;
        }

        numSamples.fetch_add(1, std::memory_order_relaxed);
        enumerateBacktracesForAllThreads(callback, cache, measureCost);
    }
    pthread_cleanup_pop(1);
    return nullptr;
}

} // namespace

SamplingProfiler::SamplingProfiler(std::function<void(SentryProfilingEntry*)> callback,
                                   std::uint32_t samplingRateHz,
                                   bool measureCost) :
    callback_(std::move(callback)),
    measureCost_(measureCost), cache_(std::make_shared<ThreadMetadataCache>()),
    isInitialized_(false), hasAddedExceptionKillswitchObserver_(false), isSampling_(false),
    port_(0), numSamples_(0) {
    if (SPECTO_LOG_KERN_RETURN(host_get_clock_service(mach_host_self(), SYSTEM_CLOCK, &clock_))
        != KERN_SUCCESS) {
        return;
    }
    if (SPECTO_LOG_KERN_RETURN(
          mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port_))
        != KERN_SUCCESS) {
        return;
    }
    const auto intervalNs = std::chrono::duration_cast<std::chrono::nanoseconds>(
                              std::chrono::duration<float>(1) / samplingRateHz)
                              .count();
    delaySpec_ = {.tv_sec = static_cast<unsigned int>(intervalNs / 1000000000ULL),
                  .tv_nsec = static_cast<clock_res_t>(intervalNs % 1000000000ULL)};
    isInitialized_ = true;
}

SamplingProfiler::~SamplingProfiler() {
    if (!isInitialized_) {
        return;
    }
    stopSampling();
    SPECTO_LOG_KERN_RETURN(
      mach_port_mod_refs(mach_task_self(), port_, MACH_PORT_RIGHT_RECEIVE, -1));
}

void SamplingProfiler::startSampling(std::function<void()> onThreadStart) {
    if (!isInitialized_) {
        SPECTO_LOG_WARN("startSampling is no-op because SamplingProfiler failed to initialize");
        return;
    }
    std::lock_guard<std::mutex> l(lock_);
    if (isSampling_) {
        return;
    }
    isSampling_ = true;
    if (!hasAddedExceptionKillswitchObserver_) {
        addCppExceptionKillswitchObserver([weakPtr = weak_from_this()] {
            if (auto self = weakPtr.lock()) {
                self->stopSampling();
            }
        });
        hasAddedExceptionKillswitchObserver_ = true;
    }
    numSamples_ = 0;
    thread_ = std::thread(samplingThreadMain,
                          port_,
                          clock_,
                          delaySpec_,
                          cache_,
                          callback_,
                          measureCost_,
                          std::ref(numSamples_),
                          onThreadStart);

    int policy;
    sched_param param;
    const auto pthreadHandle = thread_.native_handle();
    if (SPECTO_LOG_ERROR_RETURN(pthread_getschedparam(pthreadHandle, &policy, &param)) == 0) {
        param.sched_priority = thread::backtraceThreadPriority;
        SPECTO_LOG_ERROR_RETURN(pthread_setschedparam(pthreadHandle, policy, &param));
    }

    SPECTO_LOG_KERN_RETURN(clock_alarm(clock_, TIME_RELATIVE, delaySpec_, port_));
}

void SamplingProfiler::stopSampling() {
    if (!isInitialized_) {
        return;
    }
    std::lock_guard<std::mutex> l(lock_);
    if (!isSampling_) {
        return;
    }
    SPECTO_LOG_KERN_RETURN(pthread_cancel(thread_.native_handle()));
    thread_.join();
    isSampling_ = false;
}

bool SamplingProfiler::isSampling() {
    std::lock_guard<std::mutex> l(lock_);
    return isSampling_;
}

std::uint64_t SamplingProfiler::numSamples() {
    return numSamples_.load();
}

} // namespace darwin
} // namespace specto
