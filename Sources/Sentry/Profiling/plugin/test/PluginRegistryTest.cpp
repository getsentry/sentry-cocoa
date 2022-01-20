// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/plugin/src/Plugin.h"
#include "cpp/plugin/src/PluginRegistry.h"

#include <algorithm>

using namespace specto;

namespace {
class EnabledPlugin : public Plugin {
    void start(__unused std::shared_ptr<specto::TraceLogger> logger,
               __unused const std::shared_ptr<proto::TraceConfiguration> &configuration) override {
    }
    void end(__unused std::shared_ptr<specto::TraceLogger> logger) override { }
    void abort(__unused const proto::Error &error) override { }

    [[nodiscard]] bool shouldEnable(
      __unused const std::shared_ptr<proto::TraceConfiguration> &configuration) const override {
        return true;
    }
}; // namespace

class DisabledPlugin : public Plugin {
    void start(__unused std::shared_ptr<specto::TraceLogger> logger,
               __unused const std::shared_ptr<proto::TraceConfiguration> &configuration) override {
    }
    void end(__unused std::shared_ptr<specto::TraceLogger> logger) override { }
    void abort(__unused const proto::Error &error) override { }

    [[nodiscard]] bool shouldEnable(
      __unused const std::shared_ptr<proto::TraceConfiguration> &configuration) const override {
        return false;
    }
}; // namespace
} // namespace

TEST(PluginRegistryTest, TestRegisterPlugin) {
    const auto registry = std::make_shared<PluginRegistry>();
    const auto enabledPlugin = std::make_shared<EnabledPlugin>();
    const auto disabledPlugin = std::make_shared<DisabledPlugin>();

    registry->registerPlugin(enabledPlugin);
    registry->registerPlugin(disabledPlugin);

    const auto plugins =
      registry->pluginsForConfiguration(std::make_shared<proto::TraceConfiguration>());

    EXPECT_TRUE(std::find(plugins.cbegin(), plugins.cend(), enabledPlugin) != plugins.cend());
    EXPECT_FALSE(std::find(plugins.cbegin(), plugins.cend(), disabledPlugin) != plugins.cend());
}

TEST(PluginRegistryTest, TestUnregisterPlugin) {
    const auto registry = std::make_shared<PluginRegistry>();
    const auto enabledPlugin = std::make_shared<EnabledPlugin>();

    registry->registerPlugin(enabledPlugin);
    const auto initialPlugins =
      registry->pluginsForConfiguration(std::make_shared<proto::TraceConfiguration>());
    EXPECT_TRUE(std::find(initialPlugins.cbegin(), initialPlugins.cend(), enabledPlugin)
                != initialPlugins.cend());

    registry->unregisterPlugin(enabledPlugin);
    const auto finalPlugins =
      registry->pluginsForConfiguration(std::make_shared<proto::TraceConfiguration>());
    EXPECT_TRUE(finalPlugins.empty());
}

TEST(PluginRegistryTest, TestSize) {
    const auto registry = std::make_shared<PluginRegistry>();
    EXPECT_EQ(registry->size(), 0);
    const auto enabledPlugin = std::make_shared<EnabledPlugin>();
    const auto disabledPlugin = std::make_shared<DisabledPlugin>();

    registry->registerPlugin(enabledPlugin);
    EXPECT_EQ(registry->size(), 1);
    registry->registerPlugin(disabledPlugin);
    EXPECT_EQ(registry->size(), 2);

    registry->unregisterPlugin(enabledPlugin);
    EXPECT_EQ(registry->size(), 1);
}
