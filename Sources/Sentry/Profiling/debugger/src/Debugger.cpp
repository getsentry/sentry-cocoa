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

#include "Debugger.h"

#include "cpp/log/src/Log.h"

#include <sys/sysctl.h>
#include <unistd.h>

namespace specto::debugger {

// https://developer.apple.com/library/mac/#qa/qa2004/qa1361.html
bool attached() {
    struct kinfo_proc info;

    // Initialize the flags so that, if sysctl fails for some bizarre
    // reason, we get a predictable result.
    info.kp_proc.p_flag = 0;

    // Initialize mib, which tells sysctl the info we want, in this case
    // we're looking for information about a specific process ID.
    int mib[4];
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();

    // Call sysctl.
    auto size = sizeof(info);
    const auto junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, nullptr, 0);
    if (junk != 0) {
        SPECTO_LOG_WARN("sysctl failed while trying to get kinfo_proc\n");
        return false;
    }

    // We're being debugged if the P_TRACED flag is set.
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

} // namespace specto::debugger
