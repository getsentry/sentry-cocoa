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

#include <cstddef>

#pragma once

#define SPECTO_IS_VALID_POINTER(x) ((uintptr_t)x >= 4096)

namespace specto::memory {

enum SpectoAllocationType { kReadOnly = 0, kReadWrite = 1 };

struct AllocationRegion {
    std::size_t size;
    void *start;
    _Atomic(void *) volatile cursor;
};

/**
 * A struct that points to separate regions of memory, one writable and one read-only, surrounded by
 * guard pages. This helps avoid many concurrency and signal-time issues with memory allocation and
 * access.
 * @see Twitter Flight 2015 - iOS Crash Reporting by Matt Massicotte:
 * https://www.youtube.com/watch?v=6EsCWWXv7jg
 */
struct Allocator {
    void *buffer;
    bool protectionEnabled;
    AllocationRegion writableRegion;
    AllocationRegion readOnlyRegion;
};

typedef Allocator *AllocatorRef;

AllocatorRef initializeAllocator(std::size_t writableSpace, std::size_t readableSpace);

/** @return A pointer to a new region of memory of specified type (readonly/writeable). */
void *allocate(AllocatorRef allocator, std::size_t size, SpectoAllocationType type);

/** @return A reference to a new instance of a C string allocated in the read-only AllocationRegion.
 */
const char *readOnlyStringCopy(const char *string, AllocatorRef allocator);

/**
 * Mark the read-only AllocationRegion as non-writable.
 * @return false if protection failed, true otherwise.
 */
bool protectReadOnlyMemory(AllocatorRef allocator);

} // namespace specto::memory
