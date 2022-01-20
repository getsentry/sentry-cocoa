// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/persistence/src/TraceFileManager.h"
#include "cpp/traceconsumers/tracefile/src/TraceFileTraceConsumer.h"
#include "cpp/traceid/src/TraceID.h"
#include "cpp/traceio/testutils/TraceFileTestUtils.h"
#include "spectoproto/entry/entry_generated.pb.h"
#include "spectoproto/persistence/persistence_generated.pb.h"

using namespace specto;
using namespace specto::test;

namespace {
void writeEntry(const proto::Entry &entry,
                const std::shared_ptr<TraceFileTraceConsumer> &consumer) {
    const auto size = entry.ByteSizeLong();
    std::shared_ptr<char> buf(new char[size], std::default_delete<char[]>());
    entry.SerializeToArray(buf.get(), size);
    consumer->receiveEntryBuffer(buf, size);
}

void writeStartAndEndEntries(const std::shared_ptr<TraceFileTraceConsumer> &consumer) {
    proto::Entry startEntry;
    startEntry.set_type(proto::Entry_Type_TRACE_START);
    writeEntry(std::move(startEntry), consumer);

    proto::Entry endEntry;
    endEntry.set_type(proto::Entry_Type_TRACE_END);
    writeEntry(std::move(endEntry), consumer);
}

void removeAll(const filesystem::Path &dirPath) {
    filesystem::forEachInDirectory(dirPath, [&](auto path) { filesystem::remove(path); });
    filesystem::remove(dirPath);
}
} // namespace

class TraceFileTraceConsumerTest : public ::testing::Test {
protected:
    TraceFileTraceConsumerTest() {
        testDirectoryPath = filesystem::createTemporaryDirectory();
        testDirectoryPath.appendComponent("specto-test");
        removeAll(testDirectoryPath);
        filesystem::createDirectory(testDirectoryPath);
    }

    ~TraceFileTraceConsumerTest() override {
        removeAll(testDirectoryPath);
    }

    filesystem::Path testDirectoryPath;
};

TEST_F(TraceFileTraceConsumerTest, TestWritesTraceFileSynchronously) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<proto::PersistenceConfiguration>());

    const auto consumer =
      std::make_shared<TraceFileTraceConsumer>(fileManager, true /* synchronous */);
    consumer->start(TraceID {});
    writeStartAndEndEntries(consumer);
    consumer->end(true);

    const auto paths = fileManager->allUnuploadedTracePaths();
    EXPECT_EQ(paths.size(), 1);
    const auto decompressedTracePath = generateTempFilePath();
    lz4Decompress(paths[0], decompressedTracePath);
    EXPECT_TRUE(filesystem::exists(decompressedTracePath));

    validateTraceFile(decompressedTracePath);

    filesystem::remove(paths[0]);
    filesystem::remove(decompressedTracePath);
}

TEST_F(TraceFileTraceConsumerTest, TestWritesTraceFileAsynchronously) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<proto::PersistenceConfiguration>());

    // The IO thread(s) that write the trace file are only joined once the thread
    // pool (which is owned by the TraceFileTraceConsumer) is destructed, so create
    // a separate scope to ensure that the threads are joined and writes are completed
    // before verifying the results of the test.
    {
        const auto consumer =
          std::make_shared<TraceFileTraceConsumer>(fileManager, false /* synchronous */);
        consumer->start(TraceID {});
        writeStartAndEndEntries(consumer);
        consumer->end(true);
    }

    const auto paths = fileManager->allUnuploadedTracePaths();
    EXPECT_EQ(paths.size(), 1);
    const auto decompressedTracePath = generateTempFilePath();
    lz4Decompress(paths[0], decompressedTracePath);
    EXPECT_TRUE(filesystem::exists(decompressedTracePath));

    validateTraceFile(decompressedTracePath);

    filesystem::remove(paths[0]);
    filesystem::remove(decompressedTracePath);
}
