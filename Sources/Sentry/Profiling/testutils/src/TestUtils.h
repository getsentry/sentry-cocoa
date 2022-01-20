// Copyright (c) Specto Inc. All rights reserved.

#pragma once
#include "spectoproto/entry/entry_generated.pb.h"

#include <string>

namespace specto::test {

/** @return a random alphanumeric string of the specified length. */
std::string randomString(std::string::size_type length);

/** @return a mock Device proto. */
proto::Device deviceInfo();

/** @return a mock AppInfo proto. */
proto::AppInfo appInfo();

/**
 * Prepare some environment that is present when we initialize the SDK at launch time: our
 * top-level directory, termination marker directory, and last launch app info and device protos,
 * set to deviceInfo() and appInfo().
 */
void simulateAppLaunch();

/**
 * Write a device info proto representing an OS version prior to the one used in deviceInfo().
 */
void simulateOSUpgrade();

/**
 * Write an app info proto representing an app version prior to the one used in appInfo().
 */
void simulateAppUpgrade();

/**
 * Write the marker file that is normally written when the app enters the background.
 */
void simulateBackgroundingApp();

/**
 * @return The proto::TerminationMetadata_Reason value returned from evaluating the last process
 * exit supplying deviceInfo() and appInfo() as current launch infos.
 */
proto::TerminationMetadata_Reason previousTerminationReason();

} // namespace specto::test
