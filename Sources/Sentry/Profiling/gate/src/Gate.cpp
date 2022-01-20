// Copyright (c) Specto Inc. All rights reserved.

#include "Gate.h"

#include "GlobalConfiguration.h"
#include "Exception.h"

namespace specto::gate {

bool isTracingEnabled() noexcept {
    return configuration::getGlobalConfiguration()->enabled()
           && !SPECTO_IS_CPP_EXCEPTION_KILLSWITCH_SET();
}

bool isTraceUploadEnabled() noexcept {
    const auto config = configuration::getGlobalConfiguration();
    return config->enabled() && !SPECTO_IS_CPP_EXCEPTION_KILLSWITCH_SET()
           && (config->trace_upload().foreground_trace_upload_enabled()
               || config->trace_upload().background_trace_upload_enabled());
}

} // namespace specto::gate
