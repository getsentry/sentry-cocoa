// Copyright (c) Specto Inc. All rights reserved.

#include "TraceID.h"

#include <iomanip>
#include <random>
#include <sstream>

#ifdef __APPLE__
#include <CoreFoundation/CFUUID.h>
#elif __ANDROID__
#define RANDOM_SOURCE "/dev/urandom"
#else
#define RANDOM_SOURCE
#endif

namespace specto {

const TraceID TraceID::empty = TraceID(nullptr);

TraceID::TraceID(std::nullptr_t) {
    std::memset(uuid_, 0, sizeof(uuid_));
}

TraceID::TraceID() {
#ifdef __APPLE__
    static_assert(sizeof(UUID) == sizeof(CFUUIDBytes),
                  "UUID should be the same size as CFUUIDBytes");
    const auto uuid = CFUUIDCreate(kCFAllocatorDefault);
    const auto uuidBytes = CFUUIDGetUUIDBytes(uuid);
    std::memcpy(uuid_, &uuidBytes, sizeof(uuidBytes));
    CFRelease(uuid);
#elif __ANDROID__
    // Using /dev/urandom to produce cryptographically secure random
    // numbers with the ChaCha20. getrandom() is API 28+.
    thread_local std::vector<uint8_t> urandomData(16);
    thread_local std::random_device rd(RANDOM_SOURCE);
    std::generate(urandomData.begin(), urandomData.end(), std::ref(rd));
    std::copy(urandomData.begin(), urandomData.end(), uuid_);

    // Per 4.4, set bits for version and `clock_seq_hi_and_reserved`
    // https://github.com/uuidjs/uuid/blob/master/src/v4.js#L15
    uuid_[6] = (uuid_[6] & 0x0f) | 0x40;
    uuid_[8] = (uuid_[8] & 0x3f) | 0x80;
#else
#error Unsupported platform!
#endif
}

TraceID::TraceID(UUID uuid) {
    std::memcpy(uuid_, uuid, sizeof(uuid_));
}

bool TraceID::isEmpty() const {
    return *this == TraceID::empty;
}

std::string TraceID::uuid() const {
    // https://stackoverflow.com/a/42451043
    std::ostringstream oss;
    for (std::size_t i = 0; i < sizeof(uuid_); i++) {
        oss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(uuid_[i]);
    }
    return oss.str();
}

void TraceID::extractBytes(UUID uuid) const {
    std::memcpy(uuid, uuid_, sizeof(uuid_));
}

bool TraceID::operator==(const TraceID& other) const {
    return memcmp(this->uuid_, other.uuid_, sizeof(this->uuid_)) == 0;
}

bool TraceID::operator!=(const TraceID& other) const {
    return memcmp(this->uuid_, other.uuid_, sizeof(this->uuid_)) != 0;
}

} // namespace specto
