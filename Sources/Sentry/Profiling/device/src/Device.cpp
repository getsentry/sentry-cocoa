// Copyright (c) Specto Inc. All rights reserved.

// Adapted from Firebase Crashlytics; the original license content follows, in
// compliance with that license:

// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "Device.h"

#include "cpp/log/src/Log.h"

namespace specto::device {

constexpr auto maxNativePageSize_ = 1024 * 16;

constexpr auto minNativePageSize_ = 1024 * 4;

vm_size_t getPageSize() {
    // hw.pagesize is defined as HW_PAGESIZE, which is an int. It's important to match
    // these types. Turns out that sysctl will not init the data to zero, but it appears
    // that sysctlbyname does. This API is nicer, but that's important to keep in mind.

    auto pageSize = 0;
    auto size = sizeof(pageSize);
    SPECTO_LOG_TRACE("sizeof(pageSize): {}", size);
    if (sysctlbyname("hw.pagesize", &pageSize, &size, nullptr, 0) != 0) {
        SPECTO_LOG_WARN("sysctlbyname failed while trying to get hw.pagesize");
        return maxNativePageSize_;
    }

    // if the returned size is not the expected value, abort
    if (size != sizeof(pageSize)) {
        SPECTO_LOG_WARN("page size returned from sysctlbyname not the expected size");
        return maxNativePageSize_;
    }

    // put in some guards to make sure our size is reasonable
    if (pageSize > maxNativePageSize_) {
        SPECTO_LOG_WARN("page size returned from sysctlbyname larger than our max needed");
        return maxNativePageSize_;
    }

    if (pageSize < minNativePageSize_) {
        SPECTO_LOG_WARN("page size returned from sysctlbyname smaller than our min needed");
        return minNativePageSize_;
    }

    SPECTO_LOG_TRACE("reported page size: {}", pageSize);
    return pageSize;
}

} // namespace specto::device
