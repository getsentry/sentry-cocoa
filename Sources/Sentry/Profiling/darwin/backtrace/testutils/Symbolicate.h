// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#ifndef __APPLE__
#error Non-Apple platforms are not supported!
#endif

#include <cstdint>
#include <string>

namespace specto {
namespace test {

/** Returns the symbol name for the specified address. */
std::string symbolicate(std::uintptr_t address) noexcept;

} // namespace test
} // namespace specto
