// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/filesystem/src/Path.h"
#include "spectoproto/entry/entry_generated.pb.h"

namespace specto {
namespace process {

/**
 * Decide why the last process terminated.
 * @param appInfo App info for the current running process.
 * @param deviceInfo Device info for the current running process.
 * @return An enum value describing why the last process ended.
 */
proto::TerminationMetadata_Reason previousTerminationReason(const proto::AppInfo& appInfo,
                                                            const proto::Device& deviceInfo);

/**
 * @return A Path representing the file written when the user force-quits the app from the app
 * switcher directly from the foreground.
 */
filesystem::Path userTerminationMarkerFile();

/**
 * @brief Write the marker file signaling that the user force-quit the app from the app switcher
 * immediately from the foreground, without backgrounding first (by either switching to another
 * app or springboard).
 */
void recordUserTermination();

/**
 * @param reason A value from the termination reason proto enum.
 * @returns A string description of the termination reason.
 */
std::string nameForTerminationReason(proto::TerminationMetadata_Reason reason);

} // namespace process
} // namespace specto
