// Copyright (c) Specto Inc. All rights reserved.

#pragma once

namespace specto {
namespace gate {

/**
 * Returns whether tracing should be enabled, which depends on whether the C++ exception
 * killswitch is set and whether the global configuration is enabled.
 */
bool isTracingEnabled() noexcept;

/**
 * Returns whether trace uploads should be enabled, which depends on whether tracing is
 * enabled and whether the global configuration has either foreground or background trace
 * uploads enabled.
 */
bool isTraceUploadEnabled() noexcept;

} // namespace gate
} // namespace specto
