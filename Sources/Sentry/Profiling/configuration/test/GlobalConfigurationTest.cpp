// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/configuration/src/GlobalConfiguration.h"
#include "spectoproto/global/global_generated.pb.h"

#include <memory>

using namespace specto;
using namespace specto::configuration;

class GlobalConfigurationTest : public ::testing::Test {
protected:
    void SetUp() override {
        removeAllGlobalConfigurationChangedObserver();
        setGlobalConfiguration(nullptr);
    }
};

TEST_F(GlobalConfigurationTest, TestGetConfigurationWhenNoConfigurationSet) {
    EXPECT_FALSE(hasGlobalConfigurationInMemory());
    EXPECT_FALSE(getGlobalConfiguration()->enabled());
}

TEST_F(GlobalConfigurationTest, TestGetDefaultConfiguration) {
    EXPECT_FALSE(defaultGlobalConfiguration()->enabled());
}

TEST_F(GlobalConfigurationTest, TestSetConfiguration) {
    const auto configuration = std::make_shared<proto::GlobalConfiguration>();
    configuration->set_enabled(true);
    setGlobalConfiguration(configuration);

    EXPECT_TRUE(hasGlobalConfigurationInMemory());
    EXPECT_TRUE(getGlobalConfiguration()->enabled());
}

TEST_F(GlobalConfigurationTest, TestGlobalConfigurationChangedObserver) {
    int calledCount = 0;
    addGlobalConfigurationChangedObserver([&calledCount](__unused auto config) { calledCount++; });
    EXPECT_EQ(calledCount, 0);

    const auto configuration = std::make_shared<proto::GlobalConfiguration>();
    configuration->set_enabled(true);
    setGlobalConfiguration(configuration);
    setGlobalConfiguration(configuration);

    EXPECT_EQ(calledCount, 1);
}

TEST_F(GlobalConfigurationTest, TestSetNullConfiguration) {
    int calledCount = 0;
    addGlobalConfigurationChangedObserver([&calledCount](auto config) {
        EXPECT_NE(config, nullptr);
        calledCount++;
    });
    EXPECT_EQ(calledCount, 0);

    setGlobalConfiguration(nullptr);

    EXPECT_FALSE(hasGlobalConfigurationInMemory());
    EXPECT_FALSE(getGlobalConfiguration()->enabled());
    EXPECT_EQ(calledCount, 1);
}
