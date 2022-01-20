// Copyright (c) Specto Inc. All rights reserved.

#include "TraceFileTestUtils.h"

#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/lz4stream/src/LZ4Stream.h"
#include "cpp/traceio/src/LZ4.h"
#include "cpp/traceio/src/TraceFileWriter.h"
#include "cpp/util/src/ScopeGuard.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <algorithm>
#include <arpa/inet.h>
#include <fstream>
#include <iterator>
#include <vector>

namespace specto::test {

void validateTraceFile(const filesystem::Path &path) {
    readTraceFile(
      path,
      [](const auto entryIndex, const auto entry) {
          if (entryIndex == 0 && entry.type() != proto::Entry_Type_TRACE_START) {
              throw std::runtime_error("Invalid type for first entry");
          } else if (entryIndex == 1 && entry.type() != proto::Entry_Type_TRACE_END) {
              throw std::runtime_error("Invalid type for second entry");
          }
      },
      2 /* limit */);
}

void readTraceFile(const filesystem::Path &path,
                   std::function<void(std::size_t, proto::Entry)> entryHandler,
                   std::size_t limit) {
    std::ifstream inputStream(path.string(), std::ios_base::in | std::ios_base::binary);
    SPECTO_DEFER(inputStream.close());

    const auto headerSize = sizeof(kSpectoFileHeader) - 1; // drop null byte
    char headerBuf[headerSize];
    if (!inputStream.read(headerBuf, headerSize)) {
        throw std::runtime_error("Failed to read trace file header");
    }
    if (std::memcmp(headerBuf, kSpectoFileHeader, headerSize) != 0) {
        throw std::runtime_error("Invalid trace file header");
    }

    std::remove_const<decltype(kSpectoFileVersion)>::type fileVersion;
    if (!inputStream.read(reinterpret_cast<char *>(&fileVersion), sizeof(fileVersion))) {
        throw std::runtime_error("Failed to read trace file version");
    }
    fileVersion = ntohs(fileVersion);
    if (fileVersion != kSpectoFileVersion) {
        throw std::runtime_error("Invalid trace file version");
    }

    if (limit == 0) {
        limit = SIZE_MAX;
    }
    for (std::size_t entryIndex = 0; entryIndex < limit; entryIndex++) {
        std::uint32_t entrySize;
        if (!inputStream.read(reinterpret_cast<char *>(&entrySize), sizeof(entrySize))) {
            if (inputStream.eof()) {
                break;
            } else {
                throw std::runtime_error("Failed to read entry size");
            }
        }
        entrySize = ntohl(entrySize);

        if (entrySize <= 0) {
            throw std::runtime_error("Invalid entry size");
        }

        char entryBuf[entrySize];
        if (!inputStream.read(entryBuf, entrySize)) {
            throw std::runtime_error("Failed to read entry bytes");
        }
        proto::Entry entry;
        entry.ParseFromArray(entryBuf, entrySize);
        entryHandler(entryIndex, std::move(entry));
    }
}

filesystem::Path generateTempFilePath() {
    auto tempPath = filesystem::temporaryDirectoryPath();
    char filename[] = "specto-test-XXXXXX";
    tempPath.appendComponent(std::string(mktemp(filename)));
    return tempPath;
}

void lz4Decompress(const filesystem::Path &inputPath, const filesystem::Path &outputPath) {
    std::ifstream inputStream(inputPath.string(), std::ios_base::in | std::ios_base::binary);
    SPECTO_DEFER(inputStream.close());

    std::ofstream outputStream(outputPath.string(), std::ios_base::out | std::ios_base::binary);
    SPECTO_DEFER(outputStream.close());

    lz4_stream::istream lz4Stream(inputStream);
    std::copy(std::istreambuf_iterator<char>(lz4Stream),
              std::istreambuf_iterator<char>(),
              std::ostreambuf_iterator<char>(outputStream));
}

namespace {
template<class Index>
void extractTraceFromBatch(std::vector<char> buffer,
                           Index begin,
                           Index end,
                           const filesystem::Path &outputPath) {
    auto outFilePath = outputPath;
    char filename[] = "trace-XXXXXX";
    outFilePath.appendComponent(std::string(mktemp(filename)));

    std::ofstream outputStream(outFilePath.string(), std::ios_base::out | std::ios_base::binary);
    SPECTO_DEFER(outputStream.close());

    if (!outputStream.write(buffer.data() + begin, end - begin)) {
        throw std::runtime_error("Failed to write to output stream");
    }
}
} // namespace

void lz4DecompressTraceBatch(const filesystem::Path &inputPath,
                             const filesystem::Path &outputPath) {
    std::ifstream inputStream(inputPath.string(), std::ios_base::in | std::ios_base::binary);
    SPECTO_DEFER(inputStream.close());

    lz4_stream::istream lz4Stream(inputStream);
    std::vector<char> buffer((std::istreambuf_iterator<char>(lz4Stream)),
                             std::istreambuf_iterator<char>());

    std::vector<char> delimeter;
    delimeter.insert(
      delimeter.end(), kSpectoFileHeader, kSpectoFileHeader + sizeof(kSpectoFileHeader) - 1);
    const auto version = htons(kSpectoFileVersion);
    const auto versionPtr = reinterpret_cast<const char *>(&version);
    delimeter.insert(delimeter.end(), versionPtr, versionPtr + sizeof(version));

    auto current = buffer.begin();
    auto next = current;
    std::advance(next, 1);
    while (true) {
        next = std::search(next, buffer.end(), delimeter.begin(), delimeter.end());
        extractTraceFromBatch(buffer,
                              std::distance(buffer.begin(), current),
                              std::distance(buffer.begin(), next),
                              outputPath);
        if (next == buffer.end()) {
            break;
        }
        current = next;
        next = current;
        std::advance(next, 1);
    }
}

} // namespace specto::test
