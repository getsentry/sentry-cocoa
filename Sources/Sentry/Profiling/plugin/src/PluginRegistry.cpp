// Copyright (c) Specto Inc. All rights reserved.

#include "PluginRegistry.h"

#include <cassert>

namespace specto {

void PluginRegistry::registerPlugin(std::shared_ptr<Plugin> plugin) {
    assert(plugin != nullptr);
    plugins_.push_back(std::move(plugin));
}

void PluginRegistry::unregisterPlugin(const std::shared_ptr<Plugin> &plugin) {
    assert(plugin != nullptr);

    auto removalIterator = plugins_.end();
    for (auto it = plugins_.begin(); it != plugins_.end(); ++it) {
        if (*it == plugin) {
            removalIterator = it;
            break;
        }
    }
    if (removalIterator != plugins_.end()) {
        plugins_.erase(removalIterator);
    }
}

std::vector<std::shared_ptr<Plugin>> PluginRegistry::pluginsForConfiguration(
  const std::shared_ptr<proto::TraceConfiguration> &configuration) const {
    std::vector<std::shared_ptr<Plugin>> enabledPlugins;

    for (const auto &plugin : plugins_) {
        if (plugin->shouldEnable(configuration)) {
            enabledPlugins.push_back(plugin);
        }
    }

    return enabledPlugins;
}

std::size_t PluginRegistry::size() const {
    return plugins_.size();
}

} // namespace specto
