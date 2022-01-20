// Copyright (c) Specto Inc. All rights reserved.

#include "GlobalConfiguration.h"

#include "Log.h"
//#include "spectoproto./global/global_generated.pb.h"

#include <memory>
#include <mutex>

using namespace specto;

namespace {
std::shared_ptr<proto::GlobalConfiguration> gGlobalConfiguration {nullptr};
std::vector<std::function<void(std::shared_ptr<proto::GlobalConfiguration>)>>
  gGlobalConfigurationChangedObservers;
std::mutex gGlobalConfigurationLock;
} // namespace

namespace specto::configuration {

bool hasGlobalConfigurationInMemory() noexcept {
    std::lock_guard<std::mutex> l(gGlobalConfigurationLock);
    return gGlobalConfiguration != nullptr;
}

std::shared_ptr<proto::GlobalConfiguration> getGlobalConfiguration() noexcept {
    {
        std::lock_guard<std::mutex> l(gGlobalConfigurationLock);
        if (gGlobalConfiguration != nullptr) {
            SPECTO_LOG_TRACE("Returning in memory config: {}", gGlobalConfiguration->DebugString());
            return gGlobalConfiguration;
        }
    }
    auto defaultConfig = defaultGlobalConfiguration();
    SPECTO_LOG_TRACE("Returning default config: {}", defaultConfig->DebugString());
    setGlobalConfiguration(defaultConfig);
    return defaultConfig;
}

void setGlobalConfiguration(const std::shared_ptr<proto::GlobalConfiguration>& config) noexcept {
    if (config == nullptr) {
        SPECTO_LOG_TRACE("Removing in memory config");
    } else {
        SPECTO_LOG_TRACE("Setting in memory config: {}", config->DebugString());
    }
    decltype(gGlobalConfigurationChangedObservers) observers;
    {
        std::lock_guard<std::mutex> l(gGlobalConfigurationLock);
        if (gGlobalConfiguration != config) {
            gGlobalConfiguration = config;

            observers = gGlobalConfigurationChangedObservers;
        }
    }
    if (!observers.empty()) {
        const auto observerConfig = (config != nullptr) ? config : defaultGlobalConfiguration();
        for (const auto& f : observers) {
            f(observerConfig);
        }
    }
}

std::shared_ptr<proto::GlobalConfiguration> defaultGlobalConfiguration() noexcept {
    auto configuration = std::make_shared<proto::GlobalConfiguration>();
    configuration->set_enabled(false);

    configuration->mutable_persistence()->set_max_cache_age_ms(24 * 60 * 60 * 1000); // 24 hours
    configuration->mutable_persistence()->set_max_cache_count(25);
    configuration->mutable_persistence()->set_min_disk_space_bytes(500 * 1000 * 1000); // 500MB

    configuration->mutable_trace_upload()->set_foreground_trace_upload_enabled(true);
    configuration->mutable_trace_upload()->set_background_trace_upload_enabled(true);
    configuration->mutable_trace_upload()->set_cellular_trace_upload_enabled(false);
    configuration->mutable_trace_upload()->set_max_batch_size(10);

    configuration->mutable_auth()->set_refresh_threshold_sec(5 * 60); // 5 minutes

    return configuration;
}

void addGlobalConfigurationChangedObserver(
  std::function<void(std::shared_ptr<proto::GlobalConfiguration>)> f) {
    SPECTO_LOG_TRACE("Adding global configuration changed observer");
    if (f == nullptr) {
        return;
    }
    std::lock_guard<std::mutex> l(gGlobalConfigurationLock);
    gGlobalConfigurationChangedObservers.push_back(std::move(f));
}

void removeAllGlobalConfigurationChangedObserver() {
    std::lock_guard<std::mutex> l(gGlobalConfigurationLock);
    gGlobalConfigurationChangedObservers.clear();
}

} // namespace specto::configuration
