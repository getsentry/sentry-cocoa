// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/persistence/src/TraceFileManager.h"
#include "cpp/persistence/testutils/TestTraceFileEventObserver.h"
#include "spectoproto/persistence/persistence_generated.pb.h"

#include <algorithm>
#include <chrono>
#include <fstream>
#include <memory>
#include <thread>

using namespace specto;
using namespace specto::proto;
using namespace specto::test;

namespace {
void removeAll(const filesystem::Path &dirPath) {
    filesystem::forEachInDirectory(dirPath, [&](auto path) { filesystem::remove(path); });
    filesystem::remove(dirPath);
}
} // namespace

class TraceFileManagerTest : public ::testing::Test {
protected:
    TraceFileManagerTest() {
        testDirectoryPath = filesystem::createTemporaryDirectory();
        testDirectoryPath.appendComponent("specto-test");
        removeAll(testDirectoryPath);
        filesystem::createDirectory(testDirectoryPath);
    }

    ~TraceFileManagerTest() override {
        removeAll(testDirectoryPath);
    }

    filesystem::Path testDirectoryPath;
};

namespace {

filesystem::Path writeEmptyTrace(const std::shared_ptr<TraceFileManager> &fileManager) {
    auto path = fileManager->newTracePath(TraceID {});
    std::ofstream output(path.string());
    return path;
}

} // namespace

TEST_F(TraceFileManagerTest, TestNewTracePathDoesntExist) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    EXPECT_FALSE(filesystem::exists(fileManager->newTracePath(TraceID {})));
}

TEST_F(TraceFileManagerTest, TestMarkTraceCompletedMovesFile) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto path = writeEmptyTrace(fileManager);
    const auto newPath = fileManager->markTraceCompleted(path);

    EXPECT_NE(path, newPath);
    EXPECT_TRUE(filesystem::exists(newPath));
    EXPECT_FALSE(filesystem::exists(path));
}

TEST_F(TraceFileManagerTest, TestMarkTraceCompletedCallsObserver) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto observer = std::make_shared<TestTraceFileEventObserver>();
    fileManager->addObserver(observer);

    const auto path = writeEmptyTrace(fileManager);
    const auto newPath = fileManager->markTraceCompleted(path);

    EXPECT_TRUE(observer->calledTraceFileCompleted);
    EXPECT_EQ(observer->lastOldPath, path);
    EXPECT_EQ(observer->lastNewPath, newPath);
}

TEST_F(TraceFileManagerTest, TestMarkUploadQueuedMovesFile) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto path = writeEmptyTrace(fileManager);
    const auto newPath = fileManager->markUploadQueued(fileManager->markTraceCompleted(path));

    EXPECT_NE(path, newPath);
    EXPECT_TRUE(filesystem::exists(newPath));
    EXPECT_FALSE(filesystem::exists(path));
}

TEST_F(TraceFileManagerTest, TestMarkUploadQueuedCallsObserver) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto observer = std::make_shared<TestTraceFileEventObserver>();
    fileManager->addObserver(observer);

    const auto path = writeEmptyTrace(fileManager);
    const auto completePath = fileManager->markTraceCompleted(path);
    const auto uploadPath = fileManager->markUploadQueued(completePath);

    EXPECT_TRUE(observer->calledTraceFileUploadQueued);
    EXPECT_EQ(observer->lastOldPath, completePath);
    EXPECT_EQ(observer->lastNewPath, uploadPath);
}

TEST_F(TraceFileManagerTest, TestMarkUploadCancelledMovesFile) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto path = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    const auto uploadPath = fileManager->markUploadQueued(path);
    const auto cancelledPath = fileManager->markUploadCancelled(uploadPath);

    EXPECT_EQ(path, cancelledPath);
    EXPECT_TRUE(filesystem::exists(path));
    EXPECT_FALSE(filesystem::exists(uploadPath));
}

TEST_F(TraceFileManagerTest, TestMarkUploadCancelledCallsObserver) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto observer = std::make_shared<TestTraceFileEventObserver>();
    fileManager->addObserver(observer);

    const auto path = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    const auto uploadPath = fileManager->markUploadQueued(path);
    const auto cancelledPath = fileManager->markUploadCancelled(uploadPath);

    EXPECT_TRUE(observer->calledTraceFileUploadCancelled);
    EXPECT_EQ(observer->lastOldPath, uploadPath);
    EXPECT_EQ(observer->lastNewPath, cancelledPath);
}

TEST_F(TraceFileManagerTest, TestMarkUploadFinishedDeletesFile) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto path =
      fileManager->markUploadQueued(fileManager->markTraceCompleted(writeEmptyTrace(fileManager)));
    EXPECT_TRUE(filesystem::exists(path));

    fileManager->markUploadFinished(path);
    EXPECT_FALSE(filesystem::exists(path));
}

TEST_F(TraceFileManagerTest, TestMarkUploadFinishedCallsObserver) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto observer = std::make_shared<TestTraceFileEventObserver>();
    fileManager->addObserver(observer);

    const auto path =
      fileManager->markUploadQueued(fileManager->markTraceCompleted(writeEmptyTrace(fileManager)));
    fileManager->markUploadFinished(path);

    EXPECT_TRUE(observer->calledTraceFileUploadFinished);
    EXPECT_EQ(observer->lastOldPath, path);
}

TEST_F(TraceFileManagerTest, TestResetUploadStateMovesUploadingToPendingState) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto path1 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    const auto path2 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    const auto newPath2 = fileManager->markUploadQueued(path2);

    fileManager->resetUploadState();
    EXPECT_FALSE(filesystem::exists(newPath2));
    EXPECT_TRUE(filesystem::exists(path2));
    EXPECT_TRUE(filesystem::exists(path1));
}

TEST_F(TraceFileManagerTest, TestResetUploadStateCallsObserver) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto observer = std::make_shared<TestTraceFileEventObserver>();
    fileManager->addObserver(observer);

    const auto path = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    const auto newPath = fileManager->markUploadQueued(path);

    fileManager->resetUploadState();
    EXPECT_TRUE(observer->calledTraceFileUploadCancelled);
    EXPECT_EQ(observer->lastOldPath, newPath);
    EXPECT_EQ(observer->lastNewPath, path);
}

TEST_F(TraceFileManagerTest, TestAlwaysPrunesIncompleteTraces) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto path = writeEmptyTrace(fileManager);

    fileManager->prune();
    EXPECT_FALSE(filesystem::exists(path));
}

TEST_F(TraceFileManagerTest, TestPrunesOldestIfExceedsCountLimit) {
    const auto configuration = std::make_shared<PersistenceConfiguration>();
    configuration->set_max_cache_count(1);

    const auto fileManager = std::make_shared<TraceFileManager>(testDirectoryPath, configuration);
    const auto path1 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    filesystem::setLastWriteTime(path1, std::chrono::system_clock::now() - std::chrono::hours(1));
    const auto path2 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));

    fileManager->prune();
    EXPECT_FALSE(filesystem::exists(path1));
    EXPECT_TRUE(filesystem::exists(path2));
}

TEST_F(TraceFileManagerTest, TestPrunesTracesOlderThanMaxCacheAge) {
    const auto configuration = std::make_shared<PersistenceConfiguration>();
    configuration->set_max_cache_age_ms(10000);

    const auto fileManager = std::make_shared<TraceFileManager>(testDirectoryPath, configuration);
    const auto path1 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    const auto path2 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    filesystem::setLastWriteTime(path2, std::chrono::system_clock::now() - std::chrono::hours(1));

    fileManager->prune();
    EXPECT_FALSE(filesystem::exists(path2));
    EXPECT_TRUE(filesystem::exists(path1));
}

TEST_F(TraceFileManagerTest, TestPrunesTracesOlderThanMaxAgeAndExceedingCountLimit) {
    const auto configuration = std::make_shared<PersistenceConfiguration>();
    configuration->set_max_cache_age_ms(10000);
    configuration->set_max_cache_count(2);

    const auto fileManager = std::make_shared<TraceFileManager>(testDirectoryPath, configuration);
    const auto now = std::chrono::system_clock::now();
    const auto path1 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    filesystem::setLastWriteTime(path1, now - std::chrono::seconds(3));
    const auto path2 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    filesystem::setLastWriteTime(path2, now - std::chrono::seconds(2));
    const auto path3 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    filesystem::setLastWriteTime(path3, now - std::chrono::seconds(1));
    const auto path4 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    filesystem::setLastWriteTime(path4, now - std::chrono::seconds(10));

    fileManager->prune();

    EXPECT_FALSE(filesystem::exists(path1));
    EXPECT_FALSE(filesystem::exists(path4));
    EXPECT_TRUE(filesystem::exists(path2));
    EXPECT_TRUE(filesystem::exists(path3));
}

TEST_F(TraceFileManagerTest, TestGetUnuploadedTracePaths) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());

    const auto path1 = writeEmptyTrace(fileManager);
    const auto path2 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    filesystem::setLastWriteTime(path2, std::chrono::system_clock::now() - std::chrono::hours(1));
    const auto path3 = fileManager->markTraceCompleted(writeEmptyTrace(fileManager));
    const auto path4 =
      fileManager->markUploadQueued(fileManager->markTraceCompleted(writeEmptyTrace(fileManager)));

    const auto paths = fileManager->allUnuploadedTracePaths();
    EXPECT_TRUE(std::find(paths.cbegin(), paths.cend(), path1) == paths.cend());
    EXPECT_EQ(paths[0], path2);
    EXPECT_EQ(paths[1], path3);
    EXPECT_TRUE(std::find(paths.cbegin(), paths.cend(), path4) == paths.cend());
}

TEST_F(TraceFileManagerTest, TestPruningCallsObserver) {
    const auto fileManager = std::make_shared<TraceFileManager>(
      testDirectoryPath, std::make_shared<PersistenceConfiguration>());
    const auto observer = std::make_shared<TestTraceFileEventObserver>();
    fileManager->addObserver(observer);

    const auto path = writeEmptyTrace(fileManager);

    fileManager->prune();

    EXPECT_TRUE(observer->calledTraceFilePruned);
    EXPECT_EQ(observer->lastOldPath, path);
}
