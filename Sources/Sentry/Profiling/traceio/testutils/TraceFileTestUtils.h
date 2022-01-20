// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/filesystem/src/Path.h"

#include <functional>

namespace specto {

namespace proto {
class Entry;
} // namespace proto

namespace test {

/**
 * Validates that the decompressed trace file at the specified path
 * is valid by checking that the file has the right header, and has
 * TRACE_START and TRACE_END entries.
 *
 * @param path The path to the decompressed trace file to validate.
 * @throws `std::runtime_error` when any read or validation operation fails.
 */
void validateTraceFile(const filesystem::Path &path);

/**
 * Validates the header of a trace file and reads entries from the file
 * in order, calling the callback function for each entry.
 *
 * @param path The path to the decompressed trace file to validate.
 * @param entryHandler The callback function to call on each entry, where the first
 * parameter is the index of the entry and the second parameter is the
 * deserialized entry protobuf object.
 * @param limit An optional limit for the number of entries to read. If
 * 0, all entries are read.
 * @throws `std::runtime_error` when any read or validation operation fails.
 */
void readTraceFile(const filesystem::Path &path,
                   std::function<void(std::size_t, proto::Entry)> entryHandler,
                   std::size_t limit = 0);

/**
 * Generates a writeable path to a temporary file.
 */
filesystem::Path generateTempFilePath();

/**
 * Decompresses a LZ4-compressed file.
 * @param inputPath The path to the LZ4 compressed file to decompress.
 * @param outputPath The path to write the decompressed file to, which must be a
 * writable file path.
 */
void lz4Decompress(const filesystem::Path &inputPath, const filesystem::Path &outputPath);

/**
 * Decompresses a LZ4-compressed batch of traces.
 * @param inputPath The path to the LZ4 compressed trace batch to decompress.
 * @param outputPath The directory path to write the decompressed trace files to, which
 * must already exist. The trace files written to this directory will named with a unique
 * identifier.
 */
void lz4DecompressTraceBatch(const filesystem::Path &inputPath, const filesystem::Path &outputPath);

} // namespace test
} // namespace specto
