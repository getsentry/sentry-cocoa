// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include "gtest/gtest.h"
#pragma clang diagnostic pop

#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/logprocess/src/LogProcessor.h"
#include "cpp/lz4stream/src/LZ4Stream.h"
#include "cpp/traceio/testutils/TraceFileTestUtils.h"
#include "cpp/util/src/ScopeGuard.h"

#include <fstream>
#include <string>

using namespace specto;

namespace {
filesystem::Path tempFilePath() {
    auto tempPath = filesystem::temporaryDirectoryPath();
    char filename[] = "specto-log-XXXXXX";
    tempPath.appendComponent(std::string(mktemp(filename)));
    return tempPath;
}

void writeLog(const std::string& logContents, const filesystem::Path& outputPath) {
    std::ofstream outputStream(outputPath.string());
    SPECTO_DEFER(outputStream.close());
    outputStream << logContents;
}
} // namespace

class LogProcessorTest : public ::testing::Test {
protected:
    LogProcessorTest() :
        tempDirPath(filesystem::createTemporaryDirectory()), outputPath(tempFilePath()) { }

    ~LogProcessorTest() override {
        filesystem::forEachInDirectory(tempDirPath,
                                       [](const auto path) { filesystem::remove(path); });
        filesystem::remove(tempDirPath);
        filesystem::remove(outputPath);
    }

    filesystem::Path newLogFile(std::string name) {
        auto logPath = tempDirPath;
        logPath.appendComponent(std::move(name));
        return logPath;
    }

    std::string readOutput() {
        std::ifstream inputStream(outputPath.string());
        SPECTO_DEFER(inputStream.close());
        lz4_stream::istream lz4Stream(inputStream);
        return std::string(std::istreambuf_iterator<char>(lz4Stream), {});
    }

    filesystem::Path tempDirPath;
    filesystem::Path outputPath;
};

TEST_F(LogProcessorTest, TestSingleRotatingLogFile) {
    auto activeLogPath = newLogFile("log.txt");
    writeLog("foo", activeLogPath);
    writeLog("bar", newLogFile("log.1.txt"));

    LogProcessor processor(std::move(activeLogPath));
    EXPECT_TRUE(processor.createCompressedLogFile(outputPath));
    EXPECT_EQ(readOutput(), "bar\nfoo\n");
}

TEST_F(LogProcessorTest, TestMultipleRotatingFiles) {
    auto activeLogPath = newLogFile("log.txt");
    writeLog("foo", activeLogPath);
    writeLog("bar", newLogFile("log.3.txt"));
    writeLog("baz", newLogFile("log.1.txt"));
    writeLog("qux", newLogFile("log.2.txt"));

    LogProcessor processor(std::move(activeLogPath));
    EXPECT_TRUE(processor.createCompressedLogFile(outputPath));
    EXPECT_EQ(readOutput(), "bar\nqux\nbaz\nfoo\n");
}

TEST_F(LogProcessorTest, TestActiveLogFileOnly) {
    auto activeLogPath = newLogFile("log.txt");
    writeLog("foo", activeLogPath);

    LogProcessor processor(std::move(activeLogPath));
    EXPECT_TRUE(processor.createCompressedLogFile(outputPath));
    EXPECT_EQ(readOutput(), "foo\n");
}

TEST_F(LogProcessorTest, TestNoActiveLogFile) {
    LogProcessor processor(newLogFile("log.txt"));
    EXPECT_FALSE(processor.createCompressedLogFile(outputPath));
}

TEST_F(LogProcessorTest, TestRotatingLogFilesDeleted) {
    auto activeLogPath = newLogFile("log.txt");
    auto rotatingLogPath = newLogFile("log.1.txt");
    writeLog("foo", activeLogPath);
    writeLog("bar", rotatingLogPath);

    LogProcessor processor(activeLogPath);
    EXPECT_TRUE(processor.createCompressedLogFile(outputPath));
    EXPECT_EQ(readOutput(), "bar\nfoo\n");
    EXPECT_TRUE(filesystem::exists(activeLogPath));
    EXPECT_FALSE(filesystem::exists(rotatingLogPath));
}
