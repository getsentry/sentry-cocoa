// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/log/src/Log.h"

#include <exception>
#include <functional>
#include <string>

namespace specto {

/**
 * Adds an observer (as a function callback) that is called when the C++ exception
 * killswitch is flipped.
 * @param f The function to call when the killswitch is flipped.
 */
void addCppExceptionKillswitchObserver(std::function<void(void)> f);

namespace internal {
/**
 * Sets the state of the exception killswitch, which can be checked using
 * `isCppExceptionKillswitchSet`
 */
void setCppExceptionKillswitch(bool state) noexcept;

/**
 * Check whether the exception killswitch is set, which should be checked before attempting
 * any operations which may access corrupted state.
 *
 * If the killswitch is set, this will log an error containing information about the calling
 * function.
 */
bool isCppExceptionKillswitchSet(const std::string &fnName = "",
                                 const std::string &file = "",
                                 int line = 0) noexcept;

/**
 * Runs a lambda, handling exceptions encountered and then setting the kill switch if one occurs.
 *
 * @param func                  Lambda to run while handling exceptions
 * @param bailIfSwitchSetFunc   Lambda to run if the kill switch has been set
 * @param fnName                Name of the calling function, used for logging exceptions
 * @param file                  Source filename of the calling function, used for logging exceptions
 * @param line                  Source line of the calling function, used for logging exceptions
 */
template<typename Function1, typename Function2>
void handleCppException(Function1 &&func,
                        Function2 &&bailIfSwitchSetFunc,
                        const std::string &fnName = "",
                        const std::string &file = "",
                        int line = 0) noexcept {
    try {
        if (isCppExceptionKillswitchSet()) {
            bailIfSwitchSetFunc();
            return;
        }
        func();
    } catch (const std::exception &exception) {
        SPECTO_LOG_CRITICAL(
          "Exception raised in function {} [{}:{}]: {}", fnName, file, line, exception.what());
        /**
         * Flip the killswitch toggle so that when can prevent tracing and other
         * SDK operations when it has been set.
         */
        setCppExceptionKillswitch(true);
        bailIfSwitchSetFunc();
    }
}
} // namespace internal
} // namespace specto

/** Catches an exception thrown when executing `fn` and logs it, then lets execution proceed. */
#define _SPECTO_HANDLE_CPP_EXCEPTION(fn) \
    specto::internal::handleCppException([&]() { fn; }, [&]() {}, __func__, __FILE__, __LINE__)

/** An exception handler macro which will execute a second lambda before allowing execution */
#define _SPECTO_HANDLE_CPP_EXCEPTION_IF_ALIVE(fn, fn2) \
    specto::internal::handleCppException(              \
      [&]() { fn; }, [&]() { fn2; }, __func__, __FILE__, __LINE__)

#if defined(SPECTO_TEST_ENVIRONMENT)
#define SPECTO_HANDLE_CPP_EXCEPTION(fn) [&]() { fn; }()
#define SPECTO_HANDLE_CPP_EXCEPTION_IF_ALIVE(fn, fn2) [&]() { fn; }()
#define SPECTO_TEST_ONLY_HANDLE_CPP_EXCEPTION(fn) _SPECTO_HANDLE_CPP_EXCEPTION(fn)
#define SPECTO_TEST_ONLY_HANDLE_CPP_EXCEPTION_IF_ALIVE(fn, fn2) \
    _SPECTO_HANDLE_CPP_EXCEPTION_IF_ALIVE(fn, fn2)
#else
#define SPECTO_HANDLE_CPP_EXCEPTION(fn) _SPECTO_HANDLE_CPP_EXCEPTION(fn)
#define SPECTO_HANDLE_CPP_EXCEPTION_IF_ALIVE(fn, fn2) _SPECTO_HANDLE_CPP_EXCEPTION_IF_ALIVE(fn, fn2)
#define SPECTO_TEST_ONLY_HANDLE_CPP_EXCEPTION(fn) [&]() { fn; }()
#define SPECTO_TEST_ONLY_HANDLE_CPP_EXCEPTION_IF_ALIVE(fn, fn2) [&]() { fn; }()
#endif

/** Returns whether the exception killswitch is set, and logs the calling function info. */
#define SPECTO_IS_CPP_EXCEPTION_KILLSWITCH_SET() \
    specto::internal::isCppExceptionKillswitchSet(__func__, __FILE__, __LINE__)
