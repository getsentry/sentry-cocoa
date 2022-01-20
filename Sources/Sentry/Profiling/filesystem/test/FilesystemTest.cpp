// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/log/src/Log.h"
#include "cpp/util/src/ArraySize.h"

#include <algorithm>
#include <cstdlib>
#include <fstream>
#include <new>
#include <unistd.h>

using namespace specto;

namespace {
filesystem::Path createTemporaryFile(filesystem::Path tempDirPath) {
    tempDirPath.appendComponent("specto.XXXXXX");
    const auto length = tempDirPath.length();
    std::unique_ptr<char[]> templatePtr(new (std::nothrow) char[length + 1]());
    if (templatePtr == nullptr) {
        return filesystem::Path("");
    }
    std::strncpy(templatePtr.get(), tempDirPath.cString(), length);
    int fd;
    if (SPECTO_LOG_ERRNO(fd = mkstemp(templatePtr.get())) < 0) {
        return filesystem::Path("");
    }
    const char contents[] = "Hello, World!";
    const long contentsLength = util::countof(contents) - 1;
    if (SPECTO_LOG_ERRNO(write(fd, reinterpret_cast<const void *>(contents), contentsLength))
        < contentsLength) {
        return filesystem::Path("");
    }
    return filesystem::Path(std::string(templatePtr.get()));
}

void removeAll(const filesystem::Path &dirPath) {
    filesystem::forEachInDirectory(dirPath, [&](auto path) { filesystem::remove(path); });
    filesystem::remove(dirPath);
}
} // namespace

TEST(FilesystemTest, TestExistsReturnsFalseForNonexistentFile) {
    auto path = filesystem::temporaryDirectoryPath();
    path.appendComponent("foo.txt");
    EXPECT_FALSE(filesystem::exists(path));
}

TEST(FilesystemTest, TestExistsReturnsTrueForExistingFile) {
    const auto path = createTemporaryFile(filesystem::temporaryDirectoryPath());
    EXPECT_TRUE(filesystem::exists(path));

    filesystem::remove(path);
}

TEST(FilesystemTest, TestExistsReturnsFalseForNonexistentDirectory) {
    auto path = filesystem::temporaryDirectoryPath();
    path.appendComponent("foo");
    EXPECT_FALSE(filesystem::exists(path));
}

TEST(FilesystemTest, TestIsDirectoryReturnsFalseForNonexistentDirectory) {
    auto path = filesystem::temporaryDirectoryPath();
    path.appendComponent("foo");
    EXPECT_FALSE(filesystem::isDirectory(path));
}

TEST(FilesystemTest, TestIsDirectoryReturnsTrueForExistingFile) {
    const auto path = createTemporaryFile(filesystem::temporaryDirectoryPath());
    EXPECT_FALSE(filesystem::isDirectory(path));

    filesystem::remove(path);
}

TEST(FilesystemTest, TestTempDirPathExists) {
    const auto path = filesystem::temporaryDirectoryPath();
    EXPECT_FALSE(path.empty());
    EXPECT_TRUE(filesystem::exists(path));
    EXPECT_TRUE(filesystem::isDirectory(path));
}

TEST(FilesystemTest, TestCreateTempDirPathExists) {
    const auto path = filesystem::createTemporaryDirectory();
    EXPECT_FALSE(path.empty());
    EXPECT_TRUE(filesystem::exists(path));
    EXPECT_TRUE(filesystem::isDirectory(path));

    removeAll(path);
}

TEST(FilesystemTest, TestCreateDirectory) {
    auto path = filesystem::createTemporaryDirectory();
    path.appendComponent("foo");
    EXPECT_FALSE(filesystem::exists(path));
    EXPECT_FALSE(filesystem::isDirectory(path));

    EXPECT_TRUE(filesystem::createDirectory(path));
    EXPECT_TRUE(filesystem::exists(path));
    EXPECT_TRUE(filesystem::isDirectory(path));

    removeAll(path);
}

TEST(FilesystemTest, TestRenameFile) {
    const auto dirPath = filesystem::createTemporaryDirectory();
    const auto oldFilePath = createTemporaryFile(dirPath);
    auto newFilePath = dirPath;
    newFilePath.appendComponent("foo");
    EXPECT_TRUE(filesystem::exists(oldFilePath));
    EXPECT_FALSE(filesystem::exists(newFilePath));

    EXPECT_TRUE(filesystem::rename(oldFilePath, newFilePath));
    EXPECT_FALSE(filesystem::exists(oldFilePath));
    EXPECT_TRUE(filesystem::exists(newFilePath));

    removeAll(dirPath);
}

TEST(FilesystemTest, TestRenameDirectory) {
    const auto tempDirPath = filesystem::createTemporaryDirectory();
    auto oldDirPath = tempDirPath;
    oldDirPath.appendComponent("old");
    EXPECT_TRUE(filesystem::createDirectory(oldDirPath));
    EXPECT_TRUE(filesystem::exists(oldDirPath));
    EXPECT_TRUE(filesystem::isDirectory(oldDirPath));

    auto newDirPath = tempDirPath;
    newDirPath.appendComponent("new");
    EXPECT_FALSE(filesystem::exists(newDirPath));
    EXPECT_FALSE(filesystem::isDirectory(newDirPath));

    EXPECT_TRUE(filesystem::rename(oldDirPath, newDirPath));
    EXPECT_TRUE(filesystem::exists(newDirPath));
    EXPECT_TRUE(filesystem::isDirectory(newDirPath));
    EXPECT_FALSE(filesystem::exists(oldDirPath));
    EXPECT_FALSE(filesystem::isDirectory(oldDirPath));

    removeAll(tempDirPath);
}

TEST(FilesystemTest, TestRemoveFile) {
    const auto dirPath = filesystem::createTemporaryDirectory();
    const auto filePath = createTemporaryFile(dirPath);
    EXPECT_TRUE(filesystem::exists(filePath));

    EXPECT_TRUE(filesystem::remove(filePath));
    EXPECT_FALSE(filesystem::exists(filePath));

    removeAll(dirPath);
}

TEST(FilesystemTest, TestRemoveDirectory) {
    const auto tempDirPath = filesystem::createTemporaryDirectory();
    auto dirPath = tempDirPath;
    dirPath.appendComponent("old");
    EXPECT_TRUE(filesystem::createDirectory(dirPath));
    EXPECT_TRUE(filesystem::exists(dirPath));
    EXPECT_TRUE(filesystem::isDirectory(dirPath));

    EXPECT_TRUE(filesystem::remove(dirPath));
    EXPECT_FALSE(filesystem::exists(dirPath));
    EXPECT_FALSE(filesystem::isDirectory(dirPath));

    removeAll(tempDirPath);
}

TEST(FilesystemTest, TestRemoveFailsToRemoveNonEmptyDirectory) {
    const auto dirPath = filesystem::createTemporaryDirectory();
    const auto filePath = createTemporaryFile(dirPath);
    EXPECT_TRUE(filesystem::exists(filePath));

    EXPECT_FALSE(filesystem::remove(dirPath));
    EXPECT_TRUE(filesystem::exists(filePath));

    removeAll(dirPath);
}

TEST(FilesystemTest, TestLastWriteTime) {
    const auto dirPath = filesystem::createTemporaryDirectory();
    const auto filePath = createTemporaryFile(dirPath);
    EXPECT_TRUE(filesystem::exists(filePath));

    const auto writeTime = filesystem::lastWriteTime(filePath);
    EXPECT_NE(writeTime, std::chrono::system_clock::time_point::min());
    const auto age = decltype(writeTime)::clock::now() - writeTime;
    EXPECT_LT(std::chrono::duration_cast<std::chrono::seconds>(age).count(), 2);

    removeAll(dirPath);
}

TEST(FilesystemTest, TestSetLastWriteTime) {
    const auto dirPath = filesystem::createTemporaryDirectory();
    const auto filePath = createTemporaryFile(dirPath);
    EXPECT_TRUE(filesystem::exists(filePath));
    EXPECT_TRUE(filesystem::setLastWriteTime(
      filePath, std::chrono::system_clock::now() - std::chrono::hours(1)));
}

TEST(FilesystemTest, TestForEachInDirectory) {
    const auto tempDirPath = filesystem::createTemporaryDirectory();

    const auto oldFilePath = createTemporaryFile(tempDirPath);
    auto newFilePath = tempDirPath;
    newFilePath.appendComponent("foo.txt");
    EXPECT_TRUE(filesystem::rename(oldFilePath, newFilePath));

    auto dirPath = tempDirPath;
    dirPath.appendComponent("bar");
    EXPECT_TRUE(filesystem::createDirectory(dirPath));

    std::vector<std::string> filenames;
    filesystem::forEachInDirectory(tempDirPath,
                                   [&](auto path) { filenames.push_back(path.baseName()); });
    EXPECT_EQ(filenames.size(), 2);
    EXPECT_EQ(std::count(filenames.begin(), filenames.end(), "foo.txt"), 1);
    EXPECT_EQ(std::count(filenames.begin(), filenames.end(), "bar"), 1);

    removeAll(tempDirPath);
}

TEST(FilesystemTest, TestGetFreeSpace) {
    std::uintmax_t freeSpace;
    EXPECT_TRUE(filesystem::getFreeSpace(filesystem::temporaryDirectoryPath(), &freeSpace));
    EXPECT_GT(freeSpace, 0);
}
