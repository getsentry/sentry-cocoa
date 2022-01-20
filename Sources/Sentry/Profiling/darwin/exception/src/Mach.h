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

#pragma once

#include "cpp/filesystem/src/Filesystem.h"

#include <mach/mach.h>

namespace fs = specto::filesystem;

namespace specto::darwin::exception {

#pragma mark - Definitions

constexpr int exceptions_[] = {EXC_BAD_ACCESS, EXC_BAD_INSTRUCTION, EXC_ARITHMETIC, EXC_GUARD};

#pragma mark - Functions

/**
 * Install necessary handlers and begin monitoring the IPC ports needed to receive mach exceptions.
 * @param markerFileDirectory The directory in which marker files will be written in the event of a
 * mach exception.
 * @param logFilepath Path to the async-safe logging file.
 */
void initialize(const fs::Path& markerFileDirectory, const fs::Path& logfilePath);

/**
 * Look up the name of the specified mach exception given its integer value.
 * @param exception The query exception code.
 * @param name Indirect pointer to the C-string to be populated with the mach exception name.
 */
void exceptionNameLookup(int exception, const char** name);

/**
 * Disable mach exception handlers from doing anything other than passing on the signal to any
 * previously registered handlers.
 */
void disable();

} // namespace specto::darwin::exception
