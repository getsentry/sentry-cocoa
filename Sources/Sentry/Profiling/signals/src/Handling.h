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

#include "cpp/filesystem/src/Path.h"
#include "cpp/log/src/Log.h"
#include "cpp/memory/src/Memory.h"
#include "cpp/util/src/ArraySize.h"

#include <stack>

namespace fs = specto::filesystem;

namespace specto::signal {

/**
 * Of all the possible signals, we are only interested in the subset of them that represent process
 * termination and that are able to be caught.
 * @See `man sigaction`
 */
constexpr int fatalSignals_[] = {SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGSYS, SIGTRAP};

/**
 * Holds references to anything needed from within a running signal handler. Because heap memory
 * cannot be allocated in a signal handler, everything is allocated at the time the signal handler
 * is registered and passed through this. Defining it as a separate struct simplifies applying
 * memory protection to its contents to avoid accidental overwrites.
 */
struct ReadOnlyContext {
    volatile bool initialized;
    void* signalStack;
    const char* signalMarkerPaths[util::countof(fatalSignals_)];
    struct sigaction originalActions[util::countof(fatalSignals_)];
    stack_t originalStack;
    const char* logPath;
    spdlog::level::level_enum logLevel;
};

/**
 * Holds values that may be changed from within a signal handler. Keeping these in a separate
 * struct simplifies write-protecting the contents of ReadOnlyContext.
 */
struct ReadWriteContext {
    int logFd;
    volatile bool crashOccurred;
};

/**
 * Holds the read-only and writable contexts, along with the allocator that is used to
 * protect those regions.
 */
struct SignalHandlingContext {
    ReadOnlyContext* readonly;
    ReadWriteContext* writable;
    memory::AllocatorRef allocator;
};

/**
 * Preallocate necessary items in memory and register our handler function.
 * @param markerFileDirectoryPath Location in which to write the marker files signifying what caused
 * a signal.
 * @param logFilepath Path to the async-safe logging file.
 */
void initializeSignalHandling(const fs::Path& markerFileDirectoryPath,
                              const fs::Path& crashLogPath);

/** @returns true if we're in a reentrant call of a handler function. */
bool markAndCheckIfCrashed();

/**
 * Look up the name of the specified signal number.
 * @param signal The query signal.
 * @param name Indirect pointer to the C-string to be populated with the signal name.
 */
void signalNameLookup(int signal, const char** name);

/**
 * Re-install handlers already registered at the time we registered.
 * @returns false if installing the handler fails.
 */
bool reinstallOriginalHandlers();

/**
 * Disable signal handlers from doing anything other than passing on the signal to any previously
 * registered handlers.
 */
void disable();

} // namespace specto::signal
