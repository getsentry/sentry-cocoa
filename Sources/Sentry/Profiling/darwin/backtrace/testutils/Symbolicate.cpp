// Copyright (c) Specto Inc. All rights reserved.

#include "Symbolicate.h"

#include <dlfcn.h>

namespace specto::test {
std::string symbolicate(std::uintptr_t address) noexcept {
    if (address == 0) {
        return {};
    }
    struct dl_info info;
    if (dladdr(reinterpret_cast<void *>(address), &info) == 0) {
        return "";
    }
    return std::string(info.dli_sname);
}
} // namespace specto::test
