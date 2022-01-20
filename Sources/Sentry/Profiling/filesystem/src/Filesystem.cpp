// Copyright (c) Specto Inc. All rights reserved.

#include "Filesystem.h"

#include "Log.h"
#include "CPU.h"
#include "ScopeGuard.h"

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <memory>
#include <mutex>
#include <new>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <unistd.h>
#include <utime.h>

#if defined(__APPLE__)
#include <CoreFoundation/CoreFoundation.h>
#include <TargetConditionals.h>
#include <sys/syslimits.h>
#endif

namespace {
constexpr const char* const kTempDirEnvVars[] = {"TMPDIR", "TMP", "TEMP", "TEMPDIR"};
}

namespace specto::filesystem {
namespace {
Path pathUnderSpectoDirectory(const char* subpath) {
    auto path = spectoDirectory();
    path.appendComponent(subpath);
    return path;
}

std::string formatPath(const Path& path) {
#if defined(__APPLE__)
    return stripPathPrefix(path, spectoDirectory());
#else
    return path.string();
#endif
}

bool mkdirPath(const Path& path) {
    return SPECTO_LOG_ERRNO(mkdir(path.cString(), S_IRWXU | S_IRWXG | S_IRWXO)) == 0;
}
} // namespace

Path spectoDirectory() {
#if TARGET_OS_IPHONE
    static Path spectoDirectory;
    static std::once_flag spectoDirectoryOnceFlag;
    std::call_once(spectoDirectoryOnceFlag, []() {
        const auto homeURL = CFCopyHomeDirectoryURL();
        UInt8 homePath[PATH_MAX];
        if (!CFURLGetFileSystemRepresentation(homeURL, true, &homePath[0], (CFIndex)PATH_MAX)) {
            SPECTO_LOG_ERROR(
              "Could not retrieve file system representation of CFCopyHomeDirectoryURL");
        }
        CFRelease(homeURL);

        Path appSupportDirectory(reinterpret_cast<char*>(homePath));
        appSupportDirectory.appendComponent("Library/Application Support");
        // Check if the Application Support directory either exists or can be created. In
        // some cases, like when running logic tests outside of a host application, this
        // is not possible. In that scenario, we use a temporary directory instead.
        //
        // Using `mkdirPath` directly here instead of `createDirectory`, which contains
        // a log that calls through to `formatPath`, which causes a re-entrant call to
        // `spectoDirectory` and `std::call_once`. Whether `std::call_once` supports re-entrancy
        // is not defined by the standard: https://stackoverflow.com/a/22694959/153112
        if (exists(appSupportDirectory) || mkdirPath(appSupportDirectory)) {
            spectoDirectory = appSupportDirectory;
            spectoDirectory.appendComponent("specto");
        } else {
            SPECTO_LOG_WARN("Application Support directory at {} cannot be created, using a "
                            "temporary directory instead",
                            appSupportDirectory.string());
            spectoDirectory = createTemporaryDirectory();
        }
    });
    return spectoDirectory;
#elif defined(SPECTO_TEST_ENVIRONMENT)
    // For C++ tests only.
    static Path temporaryDirectory;
    static std::once_flag temporaryDirectoryOnceFlag;
    std::call_once(temporaryDirectoryOnceFlag,
                   []() { temporaryDirectory = createTemporaryDirectory(); });
    return temporaryDirectory;
#elif defined(__ANDROID__)
    SPECTO_LOG_ERROR("Do not call this function in android. This functionality is currently "
                     "implemented in dev.specto.android.core.internal.storage.DefaultFiles");
    abort();
#else
    SPECTO_LOG_ERROR("non-iPhone runtimes not currently supported.");
    abort();
#endif
}

Path terminationMarkerDirectory() {
    return pathUnderSpectoDirectory("termination");
}

Path appStateMarkerDirectory() {
    return pathUnderSpectoDirectory("appState");
}

Path backgroundedMarkerFile() {
    auto markerPath = appStateMarkerDirectory();
    markerPath.appendComponent("UIApplicationDidEnterBackgroundNotification");
    return markerPath;
}

Path lastLaunchAppInfoFile() {
    return pathUnderSpectoDirectory("application.dat");
}

Path debuggerAttachedMarkerFile() {
    return pathUnderSpectoDirectory("DEBUGGING");
}

Path lastLaunchDeviceInfoFile() {
    return pathUnderSpectoDirectory("system.dat");
}

Path lastLaunchTerminationMetadataFile() {
    return pathUnderSpectoDirectory("termination.dat");
}

Path crashLogPath() {
    return pathUnderSpectoDirectory("crash.log");
}

std::string stripPathPrefix(const Path& path, const Path& prefix) {
    auto pathStr = path.string();
    const auto prefixStr = prefix.string();
    if (pathStr.rfind(prefixStr, 0) == 0) {
        return pathStr.substr(prefixStr.size(), std::string::npos);
    }
    return pathStr;
}

bool exists(const Path& path) noexcept {
    errno = 0;
    if (access(path.cString(), F_OK) != 0) {
        if (errno != ENOENT) {
            SPECTO_LOG_ERROR("Filesystem.exists failed with code: {}, description: {}",
                             errno,
                             std::strerror(errno));
        }
        return false;
    }
    return true;
}

bool isDirectory(const Path& path) noexcept {
// stat64 is deprecated on Apple platforms (use stat instead), but other platforms may still use
// stat64 when compiling for 64-bit.
#if defined(__APPLE__) || defined(SPECTO_CPU_ADDRESS32)
    struct stat st;
    if (SPECTO_LOG_ERRNO(stat(path.cString(), &st)) != 0) {
        return false;
    }
#else
    struct stat64 st;
    if (SPECTO_LOG_ERRNO(stat64(path.cString(), &st)) != 0) {
        return false;
    }
#endif
    return S_ISDIR(st.st_mode) != 0;
}

bool createDirectory(const Path& path) noexcept {
    SPECTO_LOG_TRACE("Creating directory at {}", formatPath(path));
    return mkdirPath(path);
}

Path temporaryDirectoryPath() noexcept {
    for (auto kTempDirEnvVar : kTempDirEnvVars) {
        if (const char* path = std::getenv(kTempDirEnvVar)) {
            return Path(path);
        }
    }
    return Path(P_tmpdir);
}

Path createTemporaryDirectory() noexcept {
    auto tempDirPath = temporaryDirectoryPath();
    tempDirPath.appendComponent("specto.XXXXXX");
    const auto length = tempDirPath.length();
    std::unique_ptr<char[]> templatePtr(new (std::nothrow) char[length + 1]());
    if (templatePtr == nullptr) {
        return Path {};
    }
    std::strncpy(templatePtr.get(), tempDirPath.cString(), length);
    char* dirPath;
    if (SPECTO_LOG_ERRNO(dirPath = mkdtemp(templatePtr.get())) == nullptr) {
        return Path {};
    }
    return Path(std::string(dirPath));
}

bool rename(const Path& oldPath, const Path& newPath) noexcept {
    return SPECTO_LOG_ERRNO(std::rename(oldPath.cString(), newPath.cString())) == 0;
}

bool remove(const Path& path) noexcept {
    errno = 0;
    if (std::remove(path.cString()) == 0) {
        SPECTO_LOG_TRACE("Removed file at {}", formatPath(path));
        return true;
    }
    if (errno == ENOENT) {
        SPECTO_LOG_WARN("Tried to remove file at {} but it did not exist", formatPath(path));
    } else {
        SPECTO_LOG_ERROR("std::remove failed for file at {}: {}, {}",
                         formatPath(path),
                         errno,
                         std::strerror(errno));
    }
    return false;
}

std::chrono::system_clock::time_point lastWriteTime(const Path& path) noexcept {
#if defined(__APPLE__) || defined(SPECTO_CPU_ADDRESS32)
    struct stat st;
    if (SPECTO_LOG_ERRNO(stat(path.cString(), &st)) != 0) {
        return std::chrono::system_clock::time_point::min();
    }
#else
    struct stat64 st;
    if (SPECTO_LOG_ERRNO(stat64(path.cString(), &st)) != 0) {
        return std::chrono::system_clock::time_point::min();
    }
#endif
    return std::chrono::system_clock::from_time_t(st.st_mtime);
}

bool setLastWriteTime(const Path& path, const std::chrono::system_clock::time_point& timepoint) {
#if defined(__APPLE__) || defined(SPECTO_CPU_ADDRESS32)
    struct stat st;
    if (SPECTO_LOG_ERRNO(stat(path.cString(), &st)) != 0) {
        return false;
    }
#else
    struct stat64 st;
    if (SPECTO_LOG_ERRNO(stat64(path.cString(), &st)) != 0) {
        return false;
    }
#endif
    struct utimbuf times;
    times.actime = st.st_atime;
    times.modtime = std::chrono::system_clock::to_time_t(timepoint);
    return SPECTO_LOG_ERRNO(utime(path.cString(), &times)) == 0;
}

bool forEachInDirectory(const Path& dirPath, const std::function<void(Path)>& f) {
    int n;
#if defined(__APPLE__) || defined(SPECTO_CPU_ADDRESS32)
    struct dirent** namelist = nullptr;
    SPECTO_DEFER({
        if (namelist != nullptr) {
            free(namelist);
        }
    });
    if (SPECTO_LOG_ERRNO(n = scandir(dirPath.cString(), &namelist, nullptr, alphasort)) < 0) {
        return false;
    }
#else
    struct dirent64** namelist = nullptr;
    SPECTO_DEFER({
        if (namelist != nullptr) {
            free(namelist);
        }
    });
    if (SPECTO_LOG_ERRNO(n = scandir64(dirPath.cString(), &namelist, nullptr, alphasort64)) < 0) {
        return false;
    }
#endif
    for (int i = 0; i < n; i++) {
        const auto entry = namelist[i];
        SPECTO_DEFER(free(entry));
#if defined(__APPLE__)
        if (strncmp(entry->d_name, ".", entry->d_namlen) == 0) {
            continue;
        }
        if (strncmp(entry->d_name, "..", entry->d_namlen) == 0) {
            continue;
        }
#else
        if (strncmp(entry->d_name, ".", entry->d_reclen) == 0) {
            continue;
        }
        if (strncmp(entry->d_name, "..", entry->d_reclen) == 0) {
            continue;
        }
#endif
        auto filePath = dirPath;
        filePath.appendComponent(entry->d_name);
        f(std::move(filePath));
    }
    return true;
}

bool getFreeSpace(const Path& path, std::uintmax_t* spacePtr) {
    struct statvfs buf;
    if (SPECTO_LOG_ERRNO(statvfs(path.cString(), &buf)) != 0) {
        return false;
    }
    if (spacePtr != nullptr) {
        *spacePtr = buf.f_bsize * buf.f_bfree;
    }
    return true;
}

int numberOfItemsInDirectory(const Path& path) {
    int n;
#if defined(__APPLE__) || defined(SPECTO_CPU_ADDRESS32)
    if (SPECTO_LOG_ERRNO(n = scandir(path.cString(), nullptr, nullptr, alphasort)) < 0) {
        return -1;
    }
#else
    if (SPECTO_LOG_ERRNO(n = scandir64(path.cString(), nullptr, nullptr, alphasort64)) < 0) {
        return -1;
    }
#endif
    return n;
}

std::optional<Path> mostRecentlyModifiedFileInDirectory(const Path& directory) {
    std::vector<Path> files {};
    forEachInDirectory(directory, [&files](auto path) { files.push_back(path); });
    if (files.empty()) {
        return std::nullopt;
    }

    std::sort(files.begin(), files.end(), [](const Path& a, const Path& b) {
        return lastWriteTime(a) < lastWriteTime(b);
    });
    return files.back();
}

int fileDescriptorForPath(const char* path, bool append) {
    const auto mask = O_WRONLY | O_CREAT | (append ? O_APPEND : O_TRUNC);
    const auto fd = open(path, mask, 0644);
    if (fd < 0) {
        SPECTO_LOG_ERROR("Failed to open file descriptor to file at {}: errno {}",
                         formatPath(Path(std::string(path))),
                         strerror(errno));
        return -1;
    }
    return fd;
}

bool createFileAtPath(const Path& path) {
    const auto fd = fileDescriptorForPath(path.cString(), false);
    if (fd < 0) {
        SPECTO_LOG_ERROR(
          "Failed to create file at {}: errno {}", formatPath(path), strerror(errno));
        return false;
    }

    if (close(fd) < 0) {
        SPECTO_LOG_ERROR(
          "Failed to close created marker file at {}: errno {}", formatPath(path), strerror(errno));
        return false;
    }

    return true;
}

} // namespace specto::filesystem
