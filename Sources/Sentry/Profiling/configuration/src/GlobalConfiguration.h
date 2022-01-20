// Copyright (c) Specto Inc. All rights reserved.

#include "spectoproto/global/global_generated.pb.h"

namespace specto {
namespace configuration {

/**
 * Returns whether a global configuration has been set explicitly.
 */
bool hasGlobalConfigurationInMemory() noexcept;

/**
 * Get the current global configuration settings, or the default global configuration
 * if no configuration has been explicitly set.
 */
std::shared_ptr<proto::GlobalConfiguration> getGlobalConfiguration() noexcept;

/**
 * Sets the current global configuration settings.
 * @param globalConfiguration Pointer to the new configuration.
 */
void setGlobalConfiguration(const std::shared_ptr<proto::GlobalConfiguration>& config) noexcept;

/**
 * Returns the default set of global configuration values.
 */
std::shared_ptr<proto::GlobalConfiguration> defaultGlobalConfiguration() noexcept;

/**
 * Adds an observer (as a function callback) that is called when the global
 * configuration is changed.
 * @param f The function to call when the global configuration is changed.
 */
void addGlobalConfigurationChangedObserver(
  std::function<void(std::shared_ptr<proto::GlobalConfiguration>)> f);

/**
 * Removes all configuration changed observers added previously using
 * `addGlobalConfigurationChangedObserver`
 */
void removeAllGlobalConfigurationChangedObserver();

} // namespace configuration
} // namespace specto
