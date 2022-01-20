// Copyright (c) Specto Inc. All rights reserved.

#include "TestUtils.h"

#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/log/src/Log.h"
#include "cpp/process/src/Process.h"
#include "cpp/protobuf/src/Protobuf.h"

#include <random>

namespace specto::test {

std::string randomString(std::string::size_type length) {
    static const auto& chars = "0123456789"
                               "abcdefghijklmnopqrstuvwxyz"
                               "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    thread_local static std::mt19937 rg {std::random_device {}()};
    thread_local static std::uniform_int_distribution<std::string::size_type> dist(
      0, sizeof(chars) - 2);

    std::string str;
    str.reserve(length);
    while (length--) {
        str += chars[dist(rg)];
    }
    return str;
}

proto::Device deviceInfo() {
    proto::Device device;
    device.set_os_name("iOS");
    device.set_os_version("1.2.3");
    device.set_model("iPhone5,1");
    device.set_locale("en_US");
    return device;
}

proto::AppInfo appInfo() {
    proto::AppInfo appInfo;
    appInfo.set_app_id("com.test.app");
    appInfo.set_app_version("46");
    appInfo.set_platform(proto::AppInfo_Platform_IOS);
    return appInfo;
}

void simulateOSUpgrade() {
    proto::Device device;
    device.set_os_name("iOS");
    device.set_os_version("1.2.2");
    device.set_model("iPhone5,1");
    device.set_locale("en_US");
    protobuf::serializeProtobufToDataAtPath(device, filesystem::lastLaunchDeviceInfoFile());
}

void simulateAppUpgrade() {
    proto::AppInfo appInfo;
    appInfo.set_app_id("com.test.app");
    appInfo.set_app_version("45");
    appInfo.set_platform(proto::AppInfo_Platform_IOS);
    protobuf::serializeProtobufToDataAtPath(appInfo, filesystem::lastLaunchAppInfoFile());
}

void simulateAppLaunch() {
    if (!filesystem::exists(filesystem::spectoDirectory())) {
        filesystem::createDirectory(filesystem::spectoDirectory());
    }
    if (!filesystem::exists(filesystem::terminationMarkerDirectory())) {
        filesystem::createDirectory(filesystem::terminationMarkerDirectory());
    }
    if (!filesystem::exists(filesystem::appStateMarkerDirectory())) {
        filesystem::createDirectory(filesystem::appStateMarkerDirectory());
    }

    const auto lastAppInfo = appInfo();
    protobuf::serializeProtobufToDataAtPath(lastAppInfo, filesystem::lastLaunchAppInfoFile());

    const auto lastDeviceInfo = deviceInfo();
    protobuf::serializeProtobufToDataAtPath(lastDeviceInfo, filesystem::lastLaunchDeviceInfoFile());
}

void simulateBackgroundingApp() {
    SPECTO_LOG_ERRNO_VOID_RETURN(
      filesystem::createFileAtPath(filesystem::backgroundedMarkerFile()));
}

proto::TerminationMetadata_Reason previousTerminationReason() {
    return process::previousTerminationReason(appInfo(), deviceInfo());
}

} // namespace specto::test
