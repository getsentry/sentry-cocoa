// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include <array>

namespace specto {
namespace util {

/** Returns the size of a primitive array at compile time. */
template<std::size_t N, class T>
constexpr std::size_t countof(T (&)[N]) {
    return N;
}

/** Returns the size of an std::array at compile time. */
template<class Array, std::size_t N = std::tuple_size<Array>::value>
constexpr std::size_t countof(Array&) {
    return N;
}
} // namespace util
} // namespace specto
