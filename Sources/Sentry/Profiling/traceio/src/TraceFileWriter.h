// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/filesystem/src/Path.h"
#include "cpp/util/src/spimpl.h"

namespace specto {
namespace proto {
class Entry;
}

constexpr const char kSpectoFileHeader[] = "SPECTO";
constexpr std::uint16_t kSpectoFileVersion = 1;

/**
 * Writes a trace file in accordance with the Specto trace file format spec:
 * https://github.com/specto-dev/specto/blob/master/docs/trace-file-format-specification.md
 */
class TraceFileWriter {
public:
    /**
     * Creates a TraceFileWriter that writes to the file at the specified path.
     * @param path The path of the file to write to.
     * @param streamingCompression Whether the entries should be compressed as they are written. If
     * this is set to `false`, the entries will be written directly to a file, and the file will
     * be compressed when `close` is called.
     */
    explicit TraceFileWriter(filesystem::Path path, bool streamingCompression = true);

    /**
     * Writes an entry to the output stream.
     * @param buf The buffer containing the entry data to write.
     * @param size The length of the buffer.
     */
    bool writeEntry(const char *buf, std::size_t size);

    /**
     * Closes the output stream, no further data can be written.
     */
    bool close();

    TraceFileWriter(const TraceFileWriter &) = delete;
    TraceFileWriter &operator=(const TraceFileWriter &) = delete;

private:
    class Impl;
    spimpl::unique_impl_ptr<Impl> impl_;
};
} // namespace specto
