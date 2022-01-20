// Copyright (c) Specto Inc. All rights reserved.

#include "Exception.h"

#include <atomic>
#include <exception>
#include <mutex>
#include <vector>

namespace {
bool gCppExceptionKillswitchState {false};
bool gCppExceptionMessageLogged {false};
std::vector<std::function<void(void)>> gCppExceptionKillswitchObservers;
std::mutex gCppExceptionLock;
} // namespace

namespace specto {

void addCppExceptionKillswitchObserver(std::function<void(void)> f) {
    if (f == nullptr) {
        return;
    }
    std::lock_guard<std::mutex> l(gCppExceptionLock);
    gCppExceptionKillswitchObservers.push_back(std::move(f));
}

namespace internal {

void setCppExceptionKillswitch(bool state) noexcept {
    std::vector<std::function<void(void)>> observers;
    {
        std::lock_guard<std::mutex> l(gCppExceptionLock);
        const auto killswitchFlipped = (gCppExceptionKillswitchState != state) && state;
        gCppExceptionKillswitchState = state;
        if (killswitchFlipped) {
            observers = gCppExceptionKillswitchObservers;
        }
    }
    try {
        for (const auto &f : observers) {
            f();
        }
    } catch (const std::exception &e) {
        SPECTO_LOG_CRITICAL("Exception raised while notifying killswitch observers: {}", e.what());
    }
}

bool isCppExceptionKillswitchSet(const std::string &fnName,
                                 const std::string &file,
                                 int line) noexcept {
    std::lock_guard<std::mutex> l(gCppExceptionLock);
    if (gCppExceptionKillswitchState && !gCppExceptionMessageLogged) {
        SPECTO_LOG_CRITICAL(
          "Cancelling operation in function {} [{}:{}] because killswitch was set",
          fnName,
          file,
          line);
        gCppExceptionMessageLogged = true;
    }
    return gCppExceptionKillswitchState;
}

} // namespace internal
} // namespace specto
