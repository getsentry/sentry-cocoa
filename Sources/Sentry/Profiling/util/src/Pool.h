// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include <cstddef>
#include <functional>
#include <list>
#include <type_traits>

namespace specto {
namespace util {

/** Pool of recyclable values. */
template<typename T, typename... Args>
class Pool {
public:
    Pool(std::size_t limit,
         std::function<T(Args...)> constructor,
         std::function<void(T)> deleter = nullptr) :
        limit_(limit),
        constructor_(std::move(constructor)), deleter_(std::move(deleter)) { }

    ~Pool() {
        if (deleter_ != nullptr) {
            for (auto it = pool_.begin(); it != pool_.end(); ++it) {
                deleter_(std::move(*it));
            }
        }
    }

    T get(Args... args) {
        if (!pool_.empty()) {
            auto value = std::move(*pool_.begin());
            pool_.pop_front();
            return value;
        } else {
            return constructor_(args...);
        }
    }

    void recycle(T value) {
        if (pool_.size() < limit_) {
            pool_.push_back(std::move(value));
        }
    }

private:
    std::size_t limit_;
    std::function<T(Args...)> constructor_;
    std::function<void(T)> deleter_;
    std::list<T> pool_;
};

} // namespace util
} // namespace specto
