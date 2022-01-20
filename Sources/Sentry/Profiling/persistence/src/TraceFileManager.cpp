// Copyright (c) Specto Inc. All rights reserved.

#include "TraceFileManager.h"

#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/log/src/Log.h"
#include "spectoproto/persistence/persistence_generated.pb.h"

#include <algorithm>
#include <cassert>
#include <chrono>
#include <cstdint>
#include <string>
#include <utility>

namespace specto {
namespace {
filesystem::Path newPathByAppendingComponent(const filesystem::Path &path,
                                             const char *newComponent) {
    auto newPath = path;
    newPath.appendComponent(newComponent);
    return newPath;
}

void createDirectoryIfNecessary(const filesystem::Path &path) {
    if (filesystem::exists(path)) {
        if (!filesystem::isDirectory(path)) {
            throw std::invalid_argument(path.string() + " already exists but is not a directory.");
        }
    } else {
        filesystem::createDirectory(path);
    }
}

void addSuffixIfFileExists(filesystem::Path &path) {
    if (!filesystem::exists(path)) {
        return;
    }
    const auto parentPath = path.parentPath();
    const auto stem = path.stem();
    const auto extension = path.extension();

    std::uint32_t suffix = 0;
    do {
        path = parentPath;
        path.appendComponent(stem + "_" + std::to_string(suffix) + extension);
        if (++suffix == 0) {
            SPECTO_LOG_ERROR("Ran out of file suffixes for {}", path.string());
            break;
        }
    } while (filesystem::exists(path));
}

filesystem::Path pathInDirectory(const filesystem::Path &originalPath,
                                 const filesystem::Path &directoryPath) {
    auto newPath = directoryPath;
    newPath.appendComponent(originalPath.baseName());
    addSuffixIfFileExists(newPath);
    return newPath;
}
} // namespace

TraceFileManager::TraceFileManager(
  const filesystem::Path &rootDirectoryPath,
  std::shared_ptr<specto::proto::PersistenceConfiguration> configuration) :
    rootDirectoryPath_(rootDirectoryPath),
    pendingDirectoryPath_(newPathByAppendingComponent(rootDirectoryPath, "temp")),
    completeDirectoryPath_(newPathByAppendingComponent(rootDirectoryPath, "pending")),
    uploadingDirectoryPath_(newPathByAppendingComponent(rootDirectoryPath, "uploading")),
    configuration_(std::move(configuration)) {
    assert(filesystem::isDirectory(rootDirectoryPath));

    createDirectoryIfNecessary(pendingDirectoryPath_);
    createDirectoryIfNecessary(completeDirectoryPath_);
    createDirectoryIfNecessary(uploadingDirectoryPath_);
}

filesystem::Path TraceFileManager::newTracePath(TraceID traceID) {
    auto tracePath = pendingDirectoryPath_;
    tracePath.appendComponent(traceID.uuid());
    addSuffixIfFileExists(tracePath);
    SPECTO_LOG_INFO("Creating new trace at path {}", formatPath(tracePath));
    return tracePath;
}

#define SPECTO_IS_NONEXISTENT_PATH(path)                            \
    ({                                                              \
        const auto __nonexistent = !filesystem::exists(path);       \
        if (__nonexistent) {                                        \
            SPECTO_LOG_ERROR("{} doesn't exist", formatPath(path)); \
        }                                                           \
        (__nonexistent);                                            \
    })

filesystem::Path TraceFileManager::markTraceCompleted(const filesystem::Path &tracePath) {
    if (SPECTO_IS_NONEXISTENT_PATH(tracePath)) {
        return {};
    }
    if (tracePath.parentPath() != pendingDirectoryPath_) {
        SPECTO_LOG_ERROR("Expected {} to be in the pending state", formatPath(tracePath));
        return {};
    }
    SPECTO_LOG_INFO("Completed trace at path {}", formatPath(tracePath));
    auto newPath = pathInDirectory(tracePath, completeDirectoryPath_);
    filesystem::rename(tracePath, newPath);

    eventSubject_.traceFileCompleted(tracePath, newPath);
    return newPath;
}

filesystem::Path TraceFileManager::markUploadQueued(const filesystem::Path &tracePath) {
    if (SPECTO_IS_NONEXISTENT_PATH(tracePath)) {
        return {};
    }
    if (tracePath.parentPath() != completeDirectoryPath_) {
        SPECTO_LOG_ERROR("Expected {} to be in the completed state", formatPath(tracePath));
        return {};
    }
    SPECTO_LOG_INFO("Upload queued for trace at path {}", formatPath(tracePath));
    auto newPath = pathInDirectory(tracePath, uploadingDirectoryPath_);
    filesystem::rename(tracePath, newPath);

    eventSubject_.traceFileUploadQueued(tracePath, newPath);
    return newPath;
}

filesystem::Path TraceFileManager::markUploadCancelled(const filesystem::Path &tracePath) {
    if (SPECTO_IS_NONEXISTENT_PATH(tracePath)) {
        return {};
    }
    if (tracePath.parentPath() != uploadingDirectoryPath_) {
        SPECTO_LOG_ERROR("Expected {} to be in the uploading state", formatPath(tracePath));
        return {};
    }
    SPECTO_LOG_INFO("Upload cancelled for trace at path {}", formatPath(tracePath));
    auto newPath = pathInDirectory(tracePath, completeDirectoryPath_);
    filesystem::rename(tracePath, newPath);

    eventSubject_.traceFileUploadCancelled(tracePath, newPath);
    return newPath;
}

void TraceFileManager::markUploadFinished(const filesystem::Path &tracePath) {
    if (SPECTO_IS_NONEXISTENT_PATH(tracePath)) {
        return;
    }
    if (tracePath.parentPath() != uploadingDirectoryPath_) {
        SPECTO_LOG_ERROR("Expected {} to be in the uploading state", formatPath(tracePath));
        return;
    }
    SPECTO_LOG_INFO("Upload finished for trace at path {}", formatPath(tracePath));
    filesystem::remove(tracePath);
    eventSubject_.traceFileUploadFinished(tracePath);
}

void TraceFileManager::resetUploadState() {
    SPECTO_LOG_INFO("Resetting upload state");
    std::vector<filesystem::Path> pathsToMove;
    filesystem::forEachInDirectory(uploadingDirectoryPath_, [&pathsToMove](auto path) {
        pathsToMove.push_back(std::move(path));
    });
    for (const auto &path : pathsToMove) {
        const auto newPath = pathInDirectory(path, completeDirectoryPath_);
        filesystem::rename(path, newPath);
        eventSubject_.traceFileUploadCancelled(path, newPath);
    }
}

using FilesystemPathAgePair = std::pair<filesystem::Path, std::uint64_t>;
namespace {
bool sortPathAgePairs(const FilesystemPathAgePair &pair1, const FilesystemPathAgePair &pair2) {
    return pair2.second < pair1.second;
}
}; // namespace

void TraceFileManager::prune() {
    std::vector<filesystem::Path> pathsToRemove;
    filesystem::forEachInDirectory(pendingDirectoryPath_, [&pathsToRemove](auto path) {
        pathsToRemove.push_back(std::move(path));
    });

    std::uintmax_t freeSpace;
    if (filesystem::getFreeSpace(completeDirectoryPath_, &freeSpace)
        && freeSpace < configuration_->min_disk_space_bytes()) {
        filesystem::forEachInDirectory(completeDirectoryPath_, [&pathsToRemove](auto path) {
            pathsToRemove.push_back(std::move(path));
        });
    } else {
        const auto maxCacheAgeMs = configuration_->max_cache_age_ms();
        const auto maxCacheCount = configuration_->max_cache_count();
        const auto pruneByAge = maxCacheAgeMs != 0;
        const auto pruneByCount = maxCacheCount != 0;

        if (pruneByAge || pruneByCount) {
            std::vector<FilesystemPathAgePair> tracePaths;

            filesystem::forEachInDirectory(
              completeDirectoryPath_,
              [&pathsToRemove, &tracePaths, pruneByAge, pruneByCount, maxCacheAgeMs](auto path) {
                  const auto writeTime = filesystem::lastWriteTime(path);
                  const auto age = decltype(writeTime)::clock::now() - writeTime;
                  const auto ageMs =
                    std::chrono::duration_cast<std::chrono::milliseconds>(age).count();

                  if (pruneByAge && ageMs > maxCacheAgeMs) {
                      pathsToRemove.push_back(path);
                  } else if (pruneByCount) {
                      tracePaths.push_back(std::make_pair(path, ageMs));
                  }
              });

            const std::int32_t numTracesToRemove = static_cast<std::int32_t>(tracePaths.size())
                                                   - static_cast<std::int32_t>(maxCacheCount);
            if (numTracesToRemove > 0) {
                std::sort(tracePaths.begin(), tracePaths.end(), sortPathAgePairs);
                for (auto it = tracePaths.begin(); it != tracePaths.begin() + numTracesToRemove;
                     it++) {
                    pathsToRemove.push_back(it->first);
                }
            }
        }
    }

    for (const auto &path : pathsToRemove) {
        SPECTO_LOG_INFO("Pruning {}", formatPath(path));
        filesystem::remove(path);
        eventSubject_.traceFilePruned(path);
    }
}

namespace {
struct PathModificationDateComparator {
    bool operator()(const filesystem::Path &path1, const filesystem::Path &path2) const {
        return filesystem::lastWriteTime(path1) < filesystem::lastWriteTime(path2);
    }
};
} // namespace

std::vector<filesystem::Path> TraceFileManager::allUnuploadedTracePaths() const {
    std::vector<filesystem::Path> paths;
    filesystem::forEachInDirectory(completeDirectoryPath_,
                                   [&paths](auto path) { paths.push_back(path); });
    std::sort(paths.begin(), paths.end(), PathModificationDateComparator());
    return paths;
}

void TraceFileManager::addObserver(std::shared_ptr<TraceFileEventObserver> observer) {
    eventSubject_.addObserver(std::move(observer));
}

void TraceFileManager::removeObserver(std::shared_ptr<TraceFileEventObserver> observer) {
    eventSubject_.removeObserver(std::move(observer));
}

std::string TraceFileManager::formatPath(const filesystem::Path &path) {
    return filesystem::stripPathPrefix(path, rootDirectoryPath_.parentPath());
}
} // namespace specto
