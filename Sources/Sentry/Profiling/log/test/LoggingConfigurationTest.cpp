// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

// clang-format off
#include "cpp/log/src/Log.h"
#include "spdlog/spdlog.h"
// clang-format on

#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/log/src/BlockSink.h"
#include "cpp/log/src/Log.h"

#include <atomic>
#include <thread>

using namespace specto;

class LoggingConfigurationTest : public ::testing::Test {
protected:
    LoggingConfigurationTest() {
        testLogPath = filesystem::temporaryDirectoryPath();
        char filename[] = "specto-test-XXXXXX";
        testLogPath.appendComponent(std::string(mktemp(filename)));
    }

    ~LoggingConfigurationTest() override {
        filesystem::remove(testLogPath);
        spdlog::drop_all();
        spdlog::set_default_logger(nullptr);
    }

    filesystem::Path testLogPath;
};

TEST_F(LoggingConfigurationTest, TestUploadCallbackSinkCalledOnError) {
    auto calledSink = std::make_shared<std::atomic_bool>(false);
    auto sink =
      std::make_shared<specto::sinks::block_sink_mt>([calledSink]() { *calledSink = true; });

    configureLogger(testLogPath.string(), {std::move(sink)});

    SPECTO_LOG_ERROR("error");
    // The sink is called asynchronously, spin until it does.
    while (!*calledSink) {
    }

    EXPECT_TRUE(*calledSink);
}

TEST_F(LoggingConfigurationTest, TestMultiThreadedLogging) {
    configureLogger(testLogPath.string(),
                    {std::make_shared<specto::sinks::block_sink_mt>([]() {})});

    auto logFunction = [] {
        for (int i = 0; i < 10000; i++) {
            SPECTO_LOG_INFO("log");
        }
    };
    std::thread firstThread(logFunction);
    std::thread secondThread(logFunction);

    firstThread.join();
    secondThread.join();
}
