// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "Path.h"

#include <chrono>
#include <cstdint>
#include <dirent.h>
#include <functional>
#include <optional>
#include <string>

namespace specto::filesystem {

#pragma mark - Predefined paths

/** @return A Path representing the top-level directory where all our persisted files reside. */
Path spectoDirectory();

/**
 * @return A Path representing the directory in which marker files should be placed from our signal
 * handler, UIApplicationWillTerminate notification handler etc.
 */
Path terminationMarkerDirectory();

/**
 * @return A Path to the directory in which marker files are written for various UIApplication
 * lifecycle notifications.
 */
Path appStateMarkerDirectory();

/**
 * @return A Path to the file that is written when the application is backgrounded. The file will
 * be removed when the app enters the foreground.
 */
Path backgroundedMarkerFile();

/** @return A Path to the file where we persist the version of the application on each launch. */
Path lastLaunchAppInfoFile();

/** @return A Path to the marker file we write if we detect the app was launched with the debugger.
 */
Path debuggerAttachedMarkerFile();

/** @return A Path to the file where we persist the version of the system on each launch. */
Path lastLaunchDeviceInfoFile();

/**
 * @return A Path to the file where we cache the struct containing data about the previous process'
 * termination.
 * @note The actual cached values are determined by inspecting other files like the termination
 * marker, app and device info. That decision is computed in
 * specto::process::previousTerminationReason.
 */
Path lastLaunchTerminationMetadataFile();

/**
 * @return A path to the operating system's temporary directory path. This path is guaranteed to
 * exist and be a directory.
 */
Path temporaryDirectoryPath() noexcept;

/**
 * @return Path to the separate log where logging can be done safely from signal and mach exception
 * handlers.
 */
Path crashLogPath();

/**
 * Strips a path prefix from the beginning of a path.
 * @param path The path to strip the prefix from.
 * @param prefix The prefix to remove.
 * @return The remainder of the path after stripping prefix. If the path does not start with the
 * prefix, the original path is returned.
 */
std::string stripPathPrefix(const Path &path, const Path &prefix);

#pragma mark - File system operations

/** @return Whether the specified path exists on the filesystem. */
bool exists(const Path &path) noexcept;

/** @return Whether the specified path is a directory. */
bool isDirectory(const Path &path) noexcept;

/**
 * Creates a new directory at the specified path.
 * @param path The path of the directory to create.
 * @return Whether the directory was successfully created.
 */
bool createDirectory(const Path &path) noexcept;

/**
 * Creates a new temporary directory with a unique name, within the operating system's main
 * temporary directory.
 * @return The path to the newly created directory, or an empty path if directory creation
 * failed.
 */
Path createTemporaryDirectory() noexcept;

/**
 * Renames (moves) a file or directory to a new path.
 * @param oldPath The path of the file or directory to move.
 * @param newPath The path of the file or directory to move to.
 * @return Whether the rename operation was successful.
 */
bool rename(const Path &oldPath, const Path &newPath) noexcept;

/**
 * Removes a file or directory. If the path is a directory, the directory must be empty.
 * @param path The path to the file or directory to remove.
 * @return Whether the file or directory was removed successfully.
 */
bool remove(const Path &path) noexcept;

/**
 * @return The time of last modification for the file or directory at the specified path,
 * or `std::chrono::system_clock::time_point::min()` upon error.
 */
std::chrono::system_clock::time_point lastWriteTime(const Path &path) noexcept;

/**
 * Sets the last modification (write) time of the file/directory at the specified path.
 * @param path The path to modify the last write time of.
 * @param time The time to set as the last write time.
 * @return Whether the operation was successful.
 */
bool setLastWriteTime(const Path &path, const std::chrono::system_clock::time_point &timepoint);

/**
 * Iterates over all of the files in the specified directory, and calls `f` with the
 * path to each file. The files are enumerated in alphabetical order.
 * @param f The function to call for each file path.
 * @return Whether the directory was scanned successfully.
 */
bool forEachInDirectory(const Path &dirPath, const std::function<void(Path)> &f);

/**
 * Retrieves the number of bytes that are free on a mounted file system.
 * @param path A path that exists on the file system to retrieve statistics for.
 * @param spacePtr A pointer to set to the value of the free space (in byes) upon success.
 * @return Whether the operation was successful.
 */
bool getFreeSpace(const Path &path, std::uintmax_t *spacePtr);

/** @return The number of files and directories in the current directory. */
int numberOfItemsInDirectory(const Path &path);

/**
 * @parameter directory The directory in which to search for the file most recently modified.
 * @return A Path representing the last file to be modified, or std::nullopt if no files exist.
 */
std::optional<Path> mostRecentlyModifiedFileInDirectory(const Path &directory);

/**
 * Create a descriptor to a write-only file, creating it if not already existent.
 * @param path The location of the file to open.
 * @param append True if the file should be opened in append mode, false if it should be truncated
 * upon opening. Only matters if the file already exists upon opening.
 * @return A file descriptor, or -1 if the file could not be opened.
 */
int fileDescriptorForPath(const char *path, bool append);

/**
 * Create a new empty file at the specified path. If one already exists it is truncated.
 * @param path The location at which the new file should be.
 * @return true if the file exists at the location and is ready.
 * @return false if the file was not able to be fully prepared at the location.
 */
bool createFileAtPath(const Path &path);

} // namespace specto::filesystem
