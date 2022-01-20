// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/configuration/src/GlobalConfiguration.h"
#include "cpp/exception/src/Exception.h"
#include "cpp/gate/src/Gate.h"

using namespace specto;
using namespace specto::gate;

class GateTest : public ::testing::Test {
protected:
    void SetUp() override {
        configuration::removeAllGlobalConfigurationChangedObserver();
        configuration::setGlobalConfiguration(nullptr);
        internal::setCppExceptionKillswitch(false);
    }
};

TEST_F(GateTest, TestTracingDisabledByDefault) {
    EXPECT_FALSE(isTracingEnabled());
}

TEST_F(GateTest, TestTracingEnabledWhenEnabledConfigSet) {
    const auto configuration = std::make_shared<proto::GlobalConfiguration>();
    configuration->set_enabled(true);
    configuration::setGlobalConfiguration(configuration);

    EXPECT_TRUE(isTracingEnabled());
}

TEST_F(GateTest, TestTracingDisabledWhenKillswitchSet) {
    const auto configuration = std::make_shared<proto::GlobalConfiguration>();
    configuration->set_enabled(true);
    configuration::setGlobalConfiguration(configuration);
    EXPECT_TRUE(isTracingEnabled());

    internal::setCppExceptionKillswitch(true);
    EXPECT_FALSE(isTracingEnabled());
}

TEST_F(GateTest, TestTraceUploadDisabledByDefault) {
    EXPECT_FALSE(isTraceUploadEnabled());
}

TEST_F(GateTest, TestTraceUploadDisabledWhenKillswitchSet) {
    const auto configuration = std::make_shared<proto::GlobalConfiguration>();
    configuration->set_enabled(true);
    configuration->mutable_trace_upload()->set_foreground_trace_upload_enabled(true);
    configuration->mutable_trace_upload()->set_background_trace_upload_enabled(true);
    configuration::setGlobalConfiguration(configuration);
    EXPECT_TRUE(isTraceUploadEnabled());

    internal::setCppExceptionKillswitch(true);
    EXPECT_FALSE(isTraceUploadEnabled());
}

TEST_F(GateTest, TestTraceUploadDisabledWhenForegroundBackgroundUploadsDisabled) {
    const auto configuration = std::make_shared<proto::GlobalConfiguration>();
    configuration->set_enabled(true);
    configuration->mutable_trace_upload()->set_foreground_trace_upload_enabled(false);
    configuration->mutable_trace_upload()->set_background_trace_upload_enabled(false);
    configuration::setGlobalConfiguration(configuration);
    EXPECT_FALSE(isTraceUploadEnabled());
}

TEST_F(GateTest, TestTraceUploadEnabledWhenOnlyForegroundUploadEnabled) {
    const auto configuration = std::make_shared<proto::GlobalConfiguration>();
    configuration->set_enabled(true);
    configuration->mutable_trace_upload()->set_foreground_trace_upload_enabled(true);
    configuration->mutable_trace_upload()->set_background_trace_upload_enabled(false);
    configuration::setGlobalConfiguration(configuration);
    EXPECT_TRUE(isTraceUploadEnabled());
}

TEST_F(GateTest, TestTraceUploadEnabledWhenOnlyBackgroundUploadEnabled) {
    const auto configuration = std::make_shared<proto::GlobalConfiguration>();
    configuration->set_enabled(true);
    configuration->mutable_trace_upload()->set_foreground_trace_upload_enabled(false);
    configuration->mutable_trace_upload()->set_background_trace_upload_enabled(true);
    configuration::setGlobalConfiguration(configuration);
    EXPECT_TRUE(isTraceUploadEnabled());
}
