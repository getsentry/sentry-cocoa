// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/log/src/Log.h"

#include <functional>
#include <utility>

namespace specto {
namespace util {
/**
 * Based on https://oded.blog/2017/10/05/go-defer-in-cpp/
 */
class ScopeGuard {
public:
    template<typename Function>
    ScopeGuard(Function &&fn) : fn_(std::forward<Function>(fn)) { }

    ScopeGuard(ScopeGuard &&other) : fn_(std::move(other.fn_)) {
        other.fn_ = nullptr;
    }

    ~ScopeGuard() {
        if (fn_ != nullptr) {
            try {
                fn_();
            } catch (const std::exception &e) {
                SPECTO_LOG_ERROR("Exception thrown in ScopeGuard destructor: {}", e.what());
            } catch (...) {
                // special case of weird exceptions that don't inherit from std::exception,
                // we can't do much here besides prevent it from crashing.
            }
        }
    }

    ScopeGuard(const ScopeGuard &) = delete;
    void operator=(const ScopeGuard &) = delete;

private:
    std::function<void()> fn_;
};
} // namespace util
} // namespace specto

// clang-format off
#define SPECTO_CONCAT_(a, b) a ## b
#define SPECTO_CONCAT(a, b) SPECTO_CONCAT_(a, b)

/**
 * Usage example:
 * SPECTO_DEFER(close(fd))
 *
 * Multiline:
 * SPECTO_DEFER({
 *     foo();
 *     bar();
 * })
 */
#define SPECTO_DEFER(fn) specto::util::ScopeGuard SPECTO_CONCAT(__defer__, __LINE__) = [&]() { fn; }
// clang-format on
