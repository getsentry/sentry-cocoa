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

#include "Memory.h"

#include "cpp/device/src/Device.h"
#include "cpp/log/src/Log.h"

#include <cstdint>
#include <stdatomic.h>
#include <sys/mman.h>

namespace specto::memory {

namespace {

void *allocateFromRegion(AllocationRegion *region, std::size_t size) {
    void *newCursor;
    void *originalCursor;

    // Here's the idea
    // - read the current cursor
    // - compute what our new cursor should be
    // - attempt a swap
    // if the swap fails, some other thread has modified stuff, and we have to start again
    // if the swap works, everything has been updated correctly and we are done
    do {
        originalCursor = region->cursor;

        // this shouldn't happen unless we make a mistake with our size pre-computations
        if ((uintptr_t)originalCursor - (uintptr_t)region->start + size > region->size) {
            SPECTO_LOG_WARN("Unable to allocate sufficient memory, falling back to malloc");
            return malloc(size);
        }

        newCursor = (void *)((uintptr_t)originalCursor + size);
    } while (!atomic_compare_exchange_strong(&region->cursor, &originalCursor, newCursor));

    return originalCursor;
}

} // namespace

AllocatorRef initializeAllocator(std::size_t writableSpace, std::size_t readableSpace) {
    AllocatorRef allocator;
    AllocationRegion writableRegion;
    AllocationRegion readOnlyRegion;

    // | GUARD | WRITABLE_REGION | GUARD | READABLE_REGION | GUARD |

    const auto pageSize = device::getPageSize();

    readableSpace += sizeof(Allocator); // add the space for our allocator itself

    // we can only protect at the page level, so we need all of our regions to be
    // exact multples of pages.  But, we don't need anything in the special-case of zero.

    writableRegion.size = 0;
    if (writableSpace > 0) {
        writableRegion.size = ((writableSpace / pageSize) + 1) * pageSize;
    }

    readOnlyRegion.size = 0;
    if (readableSpace > 0) {
        readOnlyRegion.size = ((readableSpace / pageSize) + 1) * pageSize;
    }

    // Make one big, continous allocation, adding additional pages for our guards.  Note
    // that we cannot use malloc (or valloc) in this case, because we need to assert full
    // ownership over these allocations.  mmap is a much better choice.  We also mark these
    // pages as MAP_NOCACHE.
    const auto allocationSize = writableRegion.size + readOnlyRegion.size + pageSize * 3;
    const auto buffer = mmap(
      nullptr, allocationSize, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE | MAP_NOCACHE, -1, 0);
    if (buffer == MAP_FAILED) {
        SPECTO_LOG_ERROR("Mapping failed {}", strerror(errno));
        return nullptr;
    }

    // move our cursors into position
    writableRegion.cursor = (void *)((uintptr_t)buffer + pageSize);
    readOnlyRegion.cursor = (void *)((uintptr_t)buffer + pageSize + writableRegion.size + pageSize);
    writableRegion.start = writableRegion.cursor;
    readOnlyRegion.start = readOnlyRegion.cursor;

    SPECTO_LOG_TRACE("Mapping: buffer: {} writable: {} readonly: {}, total size: {} K",
                     buffer,
                     writableRegion.start,
                     readOnlyRegion.start,
                     allocationSize / 1024);

    // protect first guard page
    if (mprotect(buffer, pageSize, PROT_NONE) != 0) {
        SPECTO_LOG_ERROR("First guard protection failed {}", strerror(errno));
        return nullptr;
    }

    // middle guard
    if (mprotect((void *)((uintptr_t)buffer + pageSize + writableRegion.size), pageSize, PROT_NONE)
        != 0) {
        SPECTO_LOG_ERROR("Middle guard protection failed {}", strerror(errno));
        return nullptr;
    }

    // end guard
    if (mprotect((void *)((uintptr_t)buffer + pageSize + writableRegion.size + pageSize
                          + readOnlyRegion.size),
                 pageSize,
                 PROT_NONE)
        != 0) {
        SPECTO_LOG_ERROR("Last guard protection failed {}", strerror(errno));
        return nullptr;
    }

    // now, perform our first "allocation", which is to place our allocator into the read-only
    // region
    allocator = (AllocatorRef)allocateFromRegion(&readOnlyRegion, sizeof(Allocator));

    // set up its data structure
    allocator->buffer = buffer;
    allocator->protectionEnabled = false;
    allocator->readOnlyRegion = readOnlyRegion;
    allocator->writableRegion = writableRegion;

    SPECTO_LOG_TRACE("Allocator successfully created");

    return allocator;
}

void *allocate(AllocatorRef allocator, std::size_t size, SpectoAllocationType type) {
    AllocationRegion *region;

    if (!allocator) {
        // fall back to malloc in this case
        SPECTO_LOG_WARN("Allocator invalid, falling back to malloc");
        return malloc(size);
    }

    if (allocator->protectionEnabled) {
        SPECTO_LOG_WARN("Allocator already protected, falling back to malloc");
        return malloc(size);
    }

    switch (type) {
        case kReadOnly:
            region = &allocator->readOnlyRegion;
            break;
        case kReadWrite:
            region = &allocator->writableRegion;
            break;
        default:
            return nullptr;
    }

    return allocateFromRegion(region, size);
}

bool protectReadOnlyMemory(AllocatorRef allocator) {
    if (!SPECTO_IS_VALID_POINTER(allocator)) {
        SPECTO_LOG_ERROR("Invalid allocator");
        return false;
    }

    if (allocator->protectionEnabled) {
        SPECTO_LOG_WARN("Write protection already enabled");
        return true;
    }

    // This has to be done first
    allocator->protectionEnabled = true;

    vm_size_t pageSize = device::getPageSize();

    // readable region
    const auto address =
      (void *)((uintptr_t)allocator->buffer + pageSize + allocator->writableRegion.size + pageSize);

    return mprotect(address, allocator->readOnlyRegion.size, PROT_READ) == 0;
}

const char *readOnlyStringCopy(const char *string, AllocatorRef allocator) {
    if (!string) {
        return nullptr;
    }

    const auto length = strlen(string);
    const auto buffer = (char *)allocate(allocator, length + 1, kReadOnly);

    memcpy(buffer, string, length);

    buffer[length] = 0; // null-terminate

    return buffer;
}

} // namespace specto::memory
