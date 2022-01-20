// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include <cstdint>
#include <string>

namespace specto {

struct TraceID;

/** Generates IDs that are used to identify traces. */
struct TraceID {
    using UUID = std::uint8_t[16];

    static const TraceID empty;

    TraceID();
    explicit TraceID(UUID uuid);

    [[nodiscard]] bool isEmpty() const;
    [[nodiscard]] std::string uuid() const;
    void extractBytes(UUID uuid) const;

    bool operator==(const TraceID& other) const;
    bool operator!=(const TraceID& other) const;

private:
    explicit TraceID(std::nullptr_t);
    UUID uuid_;
};

} // namespace specto
