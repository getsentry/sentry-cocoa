// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "Path.h"
#include "TraceFileEventSubject.h"
#include "TraceID.h"

#include <memory>
#include <vector>

namespace specto {
namespace proto {
class PersistenceConfiguration;
} // namespace proto

/**
 * Manages trace files on the filesystem.
 */
class TraceFileManager {
public:
    /**
     * Constructs a new trace file manager.
     *
     * @param rootDirectoryPath The path of the directory to write trace files to.
     * Requirements:
     *   - This must be a valid path to an existing directory, `std::runtime_error`
     *     will be thrown otherwise.
     *   - This directory must be managed entirely by specto, there should be nothing
     *     else reading or writing to the contents of the directory.
     *   - Read/write permissions are required.
     * @param configuration Configuration for persistence behavior like cache pruning.
     */
    TraceFileManager(const filesystem::Path &rootDirectoryPath,
                     std::shared_ptr<proto::PersistenceConfiguration> configuration);

    /**
     * Returns a path to write a new trace file to. It is guaranteed that no other file
     * exists at this path.
     *
     * @param traceID That identifier of the trace for which to create a file path.
     * @return filesystem::Path The path to write the trace to.
     */
    filesystem::Path newTracePath(TraceID traceID);

    /**
     * Informs the file manager that the trace at the specified path is completed. This
     * moves the trace file to a separate location on the filesystem, and the new file
     * path is returned.
     *
     * @param tracePath The path to the trace file to mark as completed. `std::invalid_argument`
     * will be thrown if this path is invalid.
     * @return filesystem::Path The new path to the trace file once it has been
     * moved to its new location.
     */
    filesystem::Path markTraceCompleted(const filesystem::Path &tracePath);

    /**
     * Informs the file manager that an upload will start for the trace at the specified
     * path. This moves the trace file to a separate location on the filesystem, and the
     * new file path is returned.
     *
     * @param tracePath The path to the trace file to upload. `std::invalid_argument`
     * will be thrown if this path is invalid.
     * @return filesystem::Path The new path to the trace file once it has been
     * moved to its new location.
     */
    filesystem::Path markUploadQueued(const filesystem::Path &tracePath);

    /**
     * Informs the file manager that a previously queued upload has been cancelled. This
     * will move the trace file back to the original location on the filesystem, and that
     * path will be returned.
     *
     * @param tracePath The path to the trace file whose upload was cancelled.
     * `std::invalid_argument` will be thrown if this path is invalid.
     * @return filesystem::Path The new path to the trace file once it has been
     * moved to its new location.
     */
    filesystem::Path markUploadCancelled(const filesystem::Path &tracePath);

    /**
     * Informs the file manager that a previously queued upload has completed. This
     * removes the trace file from the filesystem.
     *
     * @param tracePath The path to the trace file that was uploaded. `std::invalid_argument`
     * will be thrown if this path is invalid.
     */
    void markUploadFinished(const filesystem::Path &tracePath);

    /**
     * Moves files that are currently in the uploading state back to the un-uploaded state.
     * This should be called when the file manager is first initialized after an app is
     * re-started, to clear inconsistent state from partial uploads that never completed.
     */
    void resetUploadState();

    /**
     * Prune incomplete traces and traces that exceed the cache age or total trace count
     * limit as specified in the `PersistenceConfiguration`.
     */
    void prune();

    /**
     * Returns a vector of all of the traces in the fileystem that have not been uploaded yet.
     * The traces are ordered from oldest modification date to newest.
     *
     * @return Paths of traces that have not been uploaded yet.
     */
    std::vector<filesystem::Path> allUnuploadedTracePaths() const;

    /** Add a new observer to be notified on file manager events. */
    void addObserver(std::shared_ptr<TraceFileEventObserver> observer);

    /** Remove a previously registered observer. */
    void removeObserver(std::shared_ptr<TraceFileEventObserver> observer);

    TraceFileManager(const TraceFileManager &) = delete;
    TraceFileManager &operator=(const TraceFileManager &) = delete;

private:
    filesystem::Path rootDirectoryPath_;
    filesystem::Path pendingDirectoryPath_;
    filesystem::Path completeDirectoryPath_;
    filesystem::Path uploadingDirectoryPath_;
    std::shared_ptr<proto::PersistenceConfiguration> configuration_;
    TraceFileEventSubject eventSubject_;

    std::string formatPath(const filesystem::Path &path);
};

} // namespace specto
