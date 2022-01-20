// Copyright (c) Specto Inc. All rights reserved.

#include "Process.h"

#include "Debugger.h"
#include "Filesystem.h"
#include "Protobuf.h"
#include "Handling.h"

namespace specto::process {

namespace {

constexpr auto kNormalTermination = "UIApplicationWillTerminateNotification";

std::optional<proto::TerminationMetadata_Reason> valueForSignal(const char* name) {
    if (strcmp(name, "SIGABRT") == 0) {
        return proto::TerminationMetadata_Reason_SIG_ABRT;
    } else if (strcmp(name, "SIGBUS") == 0) {
        return proto::TerminationMetadata_Reason_SIG_BUS;
    } else if (strcmp(name, "SIGFPE") == 0) {
        return proto::TerminationMetadata_Reason_SIG_FPE;
    } else if (strcmp(name, "SIGILL") == 0) {
        return proto::TerminationMetadata_Reason_SIG_ILL;
    } else if (strcmp(name, "SIGSEGV") == 0) {
        return proto::TerminationMetadata_Reason_SIG_SEGV;
    } else if (strcmp(name, "SIGSYS") == 0) {
        return proto::TerminationMetadata_Reason_SIG_SYS;
    } else if (strcmp(name, "SIGTRAP") == 0) {
        return proto::TerminationMetadata_Reason_SIG_TRAP;
    }

    return std::nullopt;
}

std::optional<proto::TerminationMetadata_Reason> valueForException(const char* name) {
    if (strcmp(name, "EXC_BAD_ACCESS") == 0) {
        return proto::TerminationMetadata_Reason_MACH_EXC_BAD_ACCESS;
    } else if (strcmp(name, "EXC_BAD_INSTRUCTION") == 0) {
        return proto::TerminationMetadata_Reason_MACH_EXC_BAD_INSTRUCTION;
    } else if (strcmp(name, "EXC_ARITHMETIC") == 0) {
        return proto::TerminationMetadata_Reason_MACH_EXC_ARITHMETIC;
    } else if (strcmp(name, "EXC_GUARD") == 0) {
        return proto::TerminationMetadata_Reason_MACH_EXC_GUARD;
    }

    return std::nullopt;
}

std::optional<proto::TerminationMetadata_Reason> observableTerminationReason() {
    const auto directory = filesystem::terminationMarkerDirectory();
    if (filesystem::exists(directory)) {
        if (const auto last = filesystem::mostRecentlyModifiedFileInDirectory(directory)) {
            // normal exit
            if (last->string().find(kNormalTermination) != std::string::npos) {
                SPECTO_LOG_DEBUG("Found normal exit marker.");
                return proto::TerminationMetadata_Reason_EXIT;
            }

            // signal
            if (const auto signal = valueForSignal(last->baseName().c_str())) {
                SPECTO_LOG_DEBUG("Found signal marker.");
                return signal;
            }

            // mach exception
            if (const auto exception = valueForException(last->baseName().c_str())) {
                SPECTO_LOG_DEBUG("Found mach exception marker.");
                return exception;
            }
        }
    }

    SPECTO_LOG_DEBUG("Found no exit marker.");
    return std::nullopt;
}

} // namespace

proto::TerminationMetadata_Reason previousTerminationReason(const proto::AppInfo& appInfo,
                                                            const proto::Device& deviceInfo) {
    if (const auto observableReason = observableTerminationReason()) {
        SPECTO_LOG_DEBUG("Found observable termination reason.");
        return *observableReason;
    }

    const auto appInfoPath = filesystem::lastLaunchAppInfoFile();
    if (!filesystem::exists(appInfoPath)) {
        SPECTO_LOG_DEBUG("No previous app info, assuming first launch.");
        return proto::TerminationMetadata_Reason_FIRST_RUN;
    }

    const auto lastAppInfo = protobuf::deserializedProtobufDataAtPath<proto::AppInfo>(appInfoPath);
    if (!lastAppInfo) {
        SPECTO_LOG_WARN("Couldn't deserialize last app info.");
        return proto::TerminationMetadata_Reason_UNKNOWN;
    }
    SPECTO_LOG_TRACE("last app version: {}; this app version: {}",
                     lastAppInfo->DebugString(),
                     appInfo.DebugString());
    if (lastAppInfo->app_version() != appInfo.app_version()) {
        SPECTO_LOG_DEBUG("Current app version is higher than last written app version. "
                         "Assuming app terminated for upgrade.");
        return proto::TerminationMetadata_Reason_APP_UPGRADE;
    }

    const auto deviceInfoPath = filesystem::lastLaunchDeviceInfoFile();
    if (!filesystem::exists(deviceInfoPath)) {
        // shouldn't happen because if we've written an app info proto (handled in previous branch)
        // then we also should have written a device info proto, but adding for defensiveness. since
        // this shouldn't happen, will mark this as UNKNOWN instead of FIRST_RUN since something
        // else probably happened to get into this branch
        SPECTO_LOG_WARN("No previous device info file written, but there was a previous app info "
                        "file. Marking as unknown termination reason.");
        return proto::TerminationMetadata_Reason_UNKNOWN;
    }

    const auto lastDeviceInfo =
      protobuf::deserializedProtobufDataAtPath<proto::Device>(deviceInfoPath);
    if (!lastDeviceInfo) {
        SPECTO_LOG_WARN("Couldn't deserialize last device info.");
        return proto::TerminationMetadata_Reason_UNKNOWN;
    }
    SPECTO_LOG_TRACE("last device version: {}; this device version: {}",
                     lastDeviceInfo->DebugString(),
                     deviceInfo.DebugString());

    if (lastDeviceInfo->os_version() != deviceInfo.os_version()) {
        SPECTO_LOG_DEBUG("Current device OS version is higher than last written device OS "
                         "version. Assuming app terminated for upgrade.");
        return proto::TerminationMetadata_Reason_OS_UPGRADE;
    }

    SPECTO_LOG_DEBUG("Could not decide previous termination reason.");
    return proto::TerminationMetadata_Reason_UNKNOWN;
}

filesystem::Path userTerminationMarkerFile() {
    auto terminationMarker = filesystem::terminationMarkerDirectory();
    terminationMarker.appendComponent(kNormalTermination);
    return terminationMarker;
}

void recordUserTermination() {
    const auto terminationMarker = userTerminationMarkerFile();
    if (!filesystem::createFileAtPath(terminationMarker)) {
        SPECTO_LOG_ERROR("Failed to record user termination.");
    }
}

std::string nameForTerminationReason(proto::TerminationMetadata_Reason reason) {
    switch (reason) {
        case proto::TerminationMetadata_Reason_UNSPECIFIED:
            return "UNSPECIFIED";
        case proto::TerminationMetadata_Reason_UNKNOWN:
            return "UNKNOWN";
        case proto::TerminationMetadata_Reason_FIRST_RUN:
            return "FIRST_RUN";
        case proto::TerminationMetadata_Reason_EXIT:
            return "EXIT";
        case proto::TerminationMetadata_Reason_OS_UPGRADE:
            return "OS_UPGRADE";
        case proto::TerminationMetadata_Reason_APP_UPGRADE:
            return "APP_UPGRADE";
        case proto::TerminationMetadata_Reason_SIG_ABRT:
            return "SIG_ABRT";
        case proto::TerminationMetadata_Reason_SIG_BUS:
            return "SIG_BUS";
        case proto::TerminationMetadata_Reason_SIG_FPE:
            return "SIG_FPE";
        case proto::TerminationMetadata_Reason_SIG_ILL:
            return "SIG_ILL";
        case proto::TerminationMetadata_Reason_SIG_SEGV:
            return "SIG_SEGV";
        case proto::TerminationMetadata_Reason_SIG_SYS:
            return "SIG_SYS";
        case proto::TerminationMetadata_Reason_SIG_TRAP:
            return "SIG_TRAP";
        case proto::TerminationMetadata_Reason_MACH_EXC_BAD_ACCESS:
            return "MACH_EXC_BAD_ACCESS";
        case proto::TerminationMetadata_Reason_MACH_EXC_BAD_INSTRUCTION:
            return "MACH_EXC_BAD_INSTRUCTION";
        case proto::TerminationMetadata_Reason_MACH_EXC_ARITHMETIC:
            return "MACH_EXC_ARITHMETIC";
        case proto::TerminationMetadata_Reason_MACH_EXC_GUARD:
            return "MACH_EXC_GUARD";
        case proto::TerminationMetadata_Reason_IOS_LAUNCH_TIMEOUT:
            return "IOS_LAUNCH_TIMEOUT";
        case proto::TerminationMetadata_Reason_OOM:
            return "OOM";
        default: {
            SPECTO_LOG_WARN("Unexpected termination reason value: {}", reason);
#if !defined(NDEBUG)
            abort();
#else
            return "UNEXPECTED";
#endif
        }
    }
}

} // namespace specto::process
