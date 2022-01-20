// Copyright (c) Specto Inc. All rights reserved.

#include "Log.h"

#include <cstdlib>

// clang-format off
#include "spdlog/sinks/rotating_file_sink.h"
#include "spdlog/pattern_formatter.h"

#ifdef __ANDROID__
#include "spdlog/sinks/android_sink.h"
#else
#include "spdlog/sinks/stdout_sinks.h"
#endif
// clang-format on

namespace specto {
namespace {
spdlog::logger *gLogger {nullptr};

void flushLogger() {
    getLogger()->flush();
}
} // namespace

void configureLogger(const std::string &logFilePath,
                     std::vector<spdlog::sink_ptr> additionalSinks,
                     bool debug) {
    std::vector<spdlog::sink_ptr> sinks {};

#ifdef __ANDROID__
    auto consoleSink = std::make_shared<spdlog::sinks::android_sink_mt>("specto", true);
#else
    auto consoleSink = std::make_shared<spdlog::sinks::stdout_sink_mt>();
#endif

#if defined(SPECTO_TEST_ENVIRONMENT)
    consoleSink->set_level(spdlog::level::trace);
#else
    // In production, the console logs (which are visible to customers) should only
    // show warn/critical/error logs. In development, we show up to the trace log
    // level for debugging purposes internal to Specto.
    consoleSink->set_level(debug ? spdlog::level::trace : spdlog::level::warn);
#endif

    // we just want to extend spdlog's default format to add the time zone to the
    // timestamp so everyone knows it's in UTC when reading console logs:
    //
    // [2021-06-18 14:41:23.985 -8:00] [specto] [trace] [TraceController.cpp:205]
    // Creating TraceLogger with timestamp 15857695326724
    //
    // see https://spdlog.docsforge.com/v1.x/3.custom-formatting/#pattern-flags
    const auto logFormat = "[%Y-%m-%d %H:%M:%S.%F %z] [%n] [%l] [%s:%#] %v";
    consoleSink->set_formatter(
      std::make_unique<spdlog::pattern_formatter>(logFormat, spdlog::pattern_time_type::utc));

    sinks.push_back(consoleSink);

    // Rotates each time the sink is created, ie. each time the library is initialized. This means
    // that we keep logs for the previous 3 runs at most. Platform libraries may delete rotated log
    // files before spdlog does automatically.
    auto fileSink =
      std::make_shared<spdlog::sinks::rotating_file_sink_mt>(logFilePath,
                                                             1024 * 1024 * 5 /* 5MB max */,
                                                             3 /* 3 rotating log files */,
                                                             true /* rotate when created */);

    // File logs contain all logs, even the ones that aren't printed to the console. In
    // production this is restricted to the debug level, since trace level logs are
    // reserved for internal Specto usage.
#if defined(SPECTO_TEST_ENVIRONMENT)
    fileSink->set_level(spdlog::level::trace);
#else
    fileSink->set_level(debug ? spdlog::level::trace : spdlog::level::debug);
#endif
    fileSink->set_formatter(
      std::make_unique<spdlog::pattern_formatter>(logFormat, spdlog::pattern_time_type::utc));
    sinks.push_back(fileSink);

    sinks.insert(sinks.end(), additionalSinks.begin(), additionalSinks.end());

    const auto logger = new spdlog::logger("specto", sinks.begin(), sinks.end());
    logger->flush_on(spdlog::level::err);

    // The first pass of filtering based on log level happens at the logger, and then
    // the second pass happens at the sink level.
#if defined(SPECTO_TEST_ENVIRONMENT)
    logger->set_level(spdlog::level::trace);
#else
    logger->set_level(debug ? spdlog::level::trace : spdlog::level::debug);
#endif
    gLogger = logger;

    if (std::atexit(flushLogger) != 0) {
        logger->error("Failed to setup atexit handler to flush logger");
    }
}

spdlog::logger *getLogger() {
    return gLogger ?: spdlog::default_logger_raw();
}

void setLogLevel(spdlog::level::level_enum level) {
    getLogger()->set_level(level);
}

} // namespace specto
