// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "Plugin.h"
#include "spectoproto/trace/configuration_generated.pb.h"

#include <cstddef>
#include <memory>
#include <vector>

namespace specto {

/** Manages the registration of trace plugins. */
class PluginRegistry {
public:
    /**
     * Registers a new plugin.
     *
     * @param plugin The plugin to register.
     */
    void registerPlugin(std::shared_ptr<Plugin> plugin);

    /**
     * Unregisters a previously registered plugin.
     *
     * @param plugin The plugin to unregister. If the plugin wasn't previously registered,
     * this method has no effect.
     */
    void unregisterPlugin(const std::shared_ptr<Plugin> &plugin);

    /**
     * Returns a list of plugins that should be enabled for the specified configuration.
     *
     * @param configuration The trace configuration.
     * @return List of plugin instances that should be enabled.
     */
    std::vector<std::shared_ptr<Plugin>> pluginsForConfiguration(
      const std::shared_ptr<proto::TraceConfiguration> &configuration) const;

    /** Returns the total number of registered plugins. */
    std::size_t size() const;

private:
    std::vector<std::shared_ptr<Plugin>> plugins_;
};

} // namespace specto
