// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#include <gtest/gtest.h>
#pragma clang diagnostic pop
#pragma clang diagnostic pop

#include "cpp/darwin/exception/src/Mach.h"
#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/process/src/Process.h"
#include "cpp/signals/src/Handling.h"
#include "cpp/testutils/src/TestUtils.h"
#include "cpp/util/src/ArraySize.h"
#include "spectoproto/appinfo/appinfo_generated.pb.h"
#include "spectoproto/device/device_generated.pb.h"

#include <array>

namespace exc = specto::darwin::exception;
namespace proto = specto::proto;
namespace test = specto::test;
namespace process = specto::process;
namespace fs = specto::filesystem;
namespace sig = specto::signal;
namespace util = specto::util;

#pragma clang diagnostic push
// don't warn about the gtest TEST macros–we can't change them
#pragma clang diagnostic ignored "-Wmodernize-use-trailing-return-type"

TEST(ProcessTerminationTest, TestFirstRun) {
    EXPECT_EQ(test::previousTerminationReason(), proto::TerminationMetadata_Reason_FIRST_RUN);
}

TEST(ProcessTerminationTest, TestExit) {
    test::simulateAppLaunch();

    process::recordUserTermination();

    EXPECT_EQ(test::previousTerminationReason(), proto::TerminationMetadata_Reason_EXIT);

    fs::remove(process::userTerminationMarkerFile());
}

TEST(ProcessTerminationTest, TestUpgradedOS) {
    test::simulateAppLaunch();
    test::simulateOSUpgrade();
    EXPECT_EQ(test::previousTerminationReason(), proto::TerminationMetadata_Reason_OS_UPGRADE);
}

TEST(ProcessTerminationTest, TestUpgradedApp) {
    test::simulateAppLaunch();
    test::simulateAppUpgrade();
    EXPECT_EQ(test::previousTerminationReason(), proto::TerminationMetadata_Reason_APP_UPGRADE);
}

TEST(ProcessTerminationTest, TestSignals) {
    test::simulateAppLaunch();

    const std::array<proto::TerminationMetadata_Reason, util::countof(sig::fatalSignals_)> reasons =
      {proto::TerminationMetadata_Reason_SIG_ABRT,
       proto::TerminationMetadata_Reason_SIG_BUS,
       proto::TerminationMetadata_Reason_SIG_FPE,
       proto::TerminationMetadata_Reason_SIG_ILL,
       proto::TerminationMetadata_Reason_SIG_SEGV,
       proto::TerminationMetadata_Reason_SIG_SYS,
       proto::TerminationMetadata_Reason_SIG_TRAP};
    for (std::size_t i = 0; i < util::countof(sig::fatalSignals_); i++) {
        const char* name = nullptr;
        sig::signalNameLookup(sig::fatalSignals_[i], &name);
        auto path = fs::terminationMarkerDirectory();
        path.appendComponent(std::string(name));
        fs::createFileAtPath(path);

        EXPECT_EQ(test::previousTerminationReason(), reasons[i]);

        fs::remove(path);
    }
}

TEST(ProcessTerminationTest, TestMachExceptions) {
    test::simulateAppLaunch();

    const std::array<proto::TerminationMetadata_Reason, util::countof(exc::exceptions_)> reasons = {
      proto::TerminationMetadata_Reason_MACH_EXC_BAD_ACCESS,
      proto::TerminationMetadata_Reason_MACH_EXC_BAD_INSTRUCTION,
      proto::TerminationMetadata_Reason_MACH_EXC_ARITHMETIC,
      proto::TerminationMetadata_Reason_MACH_EXC_GUARD};
    for (std::size_t i = 0; i < util::countof(exc::exceptions_); i++) {
        const char* name = nullptr;
        exc::exceptionNameLookup(exc::exceptions_[i], &name);
        auto path = fs::terminationMarkerDirectory();
        path.appendComponent(std::string(name));
        fs::createFileAtPath(path);

        EXPECT_EQ(test::previousTerminationReason(), reasons[i]);

        fs::remove(path);
    }
}

TEST(ProcessTerminationTest, TestLaunchTimeout) {
    // TODO: not implemented yet (armcknight 6/1/20)
}

TEST(ProcessTerminationTest, TestOOM) {
    // TODO: not implemented yet (armcknight 6/1/20)
}

#pragma clang diagnostic pop
