// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/traceio/src/TraceFileWriter.h"
#include "cpp/traceio/testutils/TraceFileTestUtils.h"
#include "cpp/util/src/ScopeGuard.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <algorithm>
#include <fstream>
#include <iterator>
#include <stdexcept>

using namespace specto;
using namespace specto::test;

namespace {
bool writeStartEndEntries(TraceFileWriter &writer) {
    proto::Entry startEntry;
    startEntry.set_type(proto::Entry_Type_TRACE_START);

    const auto startEntrySize = startEntry.ByteSizeLong();
    char startEntryPayload[startEntrySize];
    startEntry.SerializeToArray(startEntryPayload, startEntrySize);
    if (!writer.writeEntry(startEntryPayload, startEntrySize)) {
        return false;
    }

    proto::Entry endEntry;
    endEntry.set_type(proto::Entry_Type_TRACE_END);

    const auto endEntrySize = endEntry.ByteSizeLong();
    char endEntryPayload[endEntrySize];
    endEntry.SerializeToArray(endEntryPayload, endEntrySize);
    if (!writer.writeEntry(endEntryPayload, endEntrySize)) {
        return false;
    }
    return true;
}
} // namespace

TEST(TraceFileWriterTest, TestWritesTraceFileWithoutStreamingCompression) {
    const auto tracePath = generateTempFilePath();
    TraceFileWriter writer {tracePath, false /* streamingCompression */};
    EXPECT_TRUE(writeStartEndEntries(writer));
    EXPECT_TRUE(writer.close());
    EXPECT_TRUE(filesystem::exists(tracePath));

    const auto decompressedTracePath = generateTempFilePath();
    lz4Decompress(tracePath, decompressedTracePath);
    EXPECT_TRUE(filesystem::exists(decompressedTracePath));

    validateTraceFile(decompressedTracePath);

    filesystem::remove(tracePath);
    filesystem::remove(decompressedTracePath);
}

TEST(TraceFileWriterTest, TestWritesTraceFileWithStreamingCompression) {
    const auto tracePath = generateTempFilePath();
    TraceFileWriter writer {tracePath, true /* streamingCompression */};
    EXPECT_TRUE(writeStartEndEntries(writer));
    EXPECT_TRUE(writer.close());
    EXPECT_TRUE(filesystem::exists(tracePath));

    const auto decompressedTracePath = generateTempFilePath();
    lz4Decompress(tracePath, decompressedTracePath);
    EXPECT_TRUE(filesystem::exists(decompressedTracePath));

    validateTraceFile(decompressedTracePath);

    filesystem::remove(tracePath);
    filesystem::remove(decompressedTracePath);
}

TEST(TraceFileWriterTest, TestWriteAndDecompressBatchTrace) {
    const auto expectedTraceCount = 2;
    std::vector<filesystem::Path> paths;
    for (int i = 0; i < expectedTraceCount; i++) {
        const auto tracePath = generateTempFilePath();
        TraceFileWriter writer {tracePath, true /* streamingCompression */};
        EXPECT_TRUE(writeStartEndEntries(writer));
        EXPECT_TRUE(writer.close());
        EXPECT_TRUE(filesystem::exists(tracePath));
        paths.push_back(tracePath);
    }

    const auto batchPath = generateTempFilePath();
    std::ofstream outputStream(batchPath.string(), std::ios_base::out | std::ios_base::binary);

    for (const auto &path : paths) {
        std::ifstream inputStream(path.string(), std::ios_base::in | std::ios_base::binary);
        SPECTO_DEFER(inputStream.close());

        std::copy(std::istreambuf_iterator<char>(inputStream),
                  std::istreambuf_iterator<char>(),
                  std::ostreambuf_iterator<char>(outputStream));
    }

    outputStream.close();
    EXPECT_TRUE(filesystem::exists(batchPath));

    const auto outputPath = filesystem::createTemporaryDirectory();
    lz4DecompressTraceBatch(batchPath, outputPath);
    filesystem::remove(batchPath);

    auto traceCount = 0;
    filesystem::forEachInDirectory(outputPath, [&traceCount](auto tracePath) {
        validateTraceFile(tracePath);
        filesystem::remove(tracePath);
        traceCount++;
    });

    EXPECT_EQ(traceCount, expectedTraceCount);
}
