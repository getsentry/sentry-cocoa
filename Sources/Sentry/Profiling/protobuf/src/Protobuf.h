// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "Filesystem.h"
#include "Path.h"
#include "Log.h"
#include "Thread.h"
#include "Time.h"
#include "ScopeGuard.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <fstream>
#include <google/protobuf/message_lite.h>
#include <optional>

namespace specto {
namespace protobuf {
namespace {
inline std::string formatPath(const filesystem::Path& path) {
#if defined(__APPLE__)
    return filesystem::stripPathPrefix(path, filesystem::spectoDirectory());
#else
    return path.string();
#endif
}
} // namespace

/**
 * Helper function to make a trace entry with the timestamp, thread ID, and
 * entry type pre-populated.
 *
 * @param type The type of the entry.
 * @param groupID Identifier used to group together entries belonging to the same span.
 * @param timestampNs The absolute timestamp in nanoseconds to record for the entry, which
 * defaults to the current absolute timestamp.
 * @param tid The ID of the thread from which the entry is being logged.
 * @return Trace entry object.
 */
proto::Entry makeEntry(proto::Entry_Type type,
                       std::string groupID = "",
                       time::Type timestampNs = time::getUptimeNs(),
                       thread::TIDType tid = thread::getCurrentTID()) noexcept;

template<typename Proto>

/**
 * @param path The location of the file from which to read the serialized protobuf data.
 * @return Either the hydrated proto object, or std::nullopt if one could not be hydrated.
 */
inline std::optional<Proto> deserializedProtobufDataAtPath(const filesystem::Path& path) {
    SPECTO_LOG_TRACE("Deserializing protobuf from file at {}", formatPath(path));
    if (!filesystem::exists(path)) {
        SPECTO_LOG_WARN("No protobuf file located at {}", formatPath(path));
        return std::nullopt;
    }

    if (filesystem::isDirectory(path)) {
        SPECTO_LOG_WARN(
          "Path {} points to directory instead of file as expected, cannot deserialize to proto",
          path.string());
        return std::nullopt;
    }

    std::ifstream input(path.string(), std::ios_base::in | std::ios_base::binary);
    SPECTO_DEFER(input.close());
    if (!input) {
        SPECTO_LOG_WARN("Couldn't open ifstream to {}", formatPath(path));
        return std::nullopt;
    }

    Proto object;
    if (!object.ParseFromIstream(&input)) {
        SPECTO_LOG_WARN("Couldn't parse proto object from data at {}", formatPath(path));
        return std::nullopt;
    }

    return object;
}

template<typename Proto>
/**
 * @param proto The proto wrapper class instance that should be serialized to data on disk.
 * @param path The location of the file to which the serialized protobuf data should be written.
 * @return true if the operation completed successfully, false otherwise.
 */
inline bool serializeProtobufToDataAtPath(Proto proto, const filesystem::Path& path) {
    SPECTO_LOG_TRACE("Serializing protobuf to file at {}", formatPath(path));
    std::ofstream output(path.string(), std::ios_base::out | std::ios_base::binary);
    SPECTO_DEFER(output.close());
    if (!output) {
        SPECTO_LOG_WARN("Couldn't open ofstream to {}", formatPath(path));
        return false;
    }

    if (!proto.SerializeToOstream(&output)) {
        SPECTO_LOG_WARN("Couldn't serialize proto object to data at {}", formatPath(path));
        return false;
    }

    return true;
}

} // namespace protobuf
} // namespace specto
