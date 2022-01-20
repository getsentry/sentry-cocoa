// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/configuration/src/GlobalConfiguration.h"
#include "cpp/exception/src/Exception.h"
#include "cpp/plugin/src/Plugin.h"
#include "cpp/plugin/src/PluginRegistry.h"
#include "cpp/protobuf/src/Protobuf.h"
#include "cpp/trace/src/TraceBufferConsumer.h"
#include "cpp/trace/src/TraceConsumer.h"
#include "cpp/trace/src/TraceController.h"
#include "cpp/trace/testutils/TestTraceConsumer.h"
#include "cpp/trace/testutils/TestTraceEventObserver.h"
#include "spectoproto/global/global_generated.pb.h"

#include <algorithm>
#include <atomic>
#include <exception>
#include <memory>
#include <thread>

using namespace specto;
using namespace specto::test;

namespace {
class EnabledPlugin : public Plugin {
public:
    void start(__unused std::shared_ptr<specto::TraceLogger> logger,
               __unused const std::shared_ptr<proto::TraceConfiguration> &configuration) override {
        if (logger != nullptr) {
            calledStartWithValidLogger = true;
        }
    }

    void end(__unused std::shared_ptr<specto::TraceLogger> logger) override {
        if (logger != nullptr) {
            calledEndWithValidLogger = true;
        }
    }

    void abort(__unused const proto::Error &error) override {
        calledAbort = true;
        lastError = error;
    }

    [[nodiscard]] bool shouldEnable(
      __unused const std::shared_ptr<proto::TraceConfiguration> &configuration) const override {
        return true;
    }

    bool calledStartWithValidLogger = false;
    bool calledEndWithValidLogger = false;
    bool calledAbort = false;
    proto::Error lastError {};
};

class DisabledPlugin : public EnabledPlugin {
    [[nodiscard]] bool shouldEnable(
      __unused const std::shared_ptr<proto::TraceConfiguration> &configuration) const override {
        return false;
    }
};

class WriterPlugin : public EnabledPlugin {
    void start(std::shared_ptr<specto::TraceLogger> logger,
               const std::shared_ptr<proto::TraceConfiguration> &configuration) {
        EnabledPlugin::start(logger, configuration);
        logger->log(protobuf::makeEntry(proto::Entry_Type_TASK_CALL));
    }

    void end(std::shared_ptr<specto::TraceLogger> logger) {
        EnabledPlugin::end(logger);
        logger->log(protobuf::makeEntry(proto::Entry_Type_BACKTRACE));
    }
};

void consumerThreadFunction(std::shared_ptr<TraceBufferConsumer> bufferConsumer) {
    bufferConsumer->startLoop();
}

std::shared_ptr<proto::TraceConfiguration> testTraceConfiguration() {
    return std::make_shared<proto::TraceConfiguration>();
}

std::shared_ptr<proto::AppInfo> createEmptyAppinfo() {
    return std::make_shared<proto::AppInfo>();
}

class TraceControllerTest : public ::testing::Test {
protected:
    void SetUp() override {
        internal::setCppExceptionKillswitch(false);
    }
};
} // namespace

TEST_F(TraceControllerTest, TestCallingStartTraceCallsObserver) {
    auto observer = std::make_shared<TestTraceEventObserver>();
    const auto controller = std::make_shared<TraceController>(
      PluginRegistry {}, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->addObserver(observer);

    controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");
    EXPECT_TRUE(observer->calledTraceStarted);
}

TEST_F(TraceControllerTest, TestCallingEndTraceCallsObserver) {
    auto observer = std::make_shared<TestTraceEventObserver>();
    const auto controller = std::make_shared<TraceController>(
      PluginRegistry {}, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->addObserver(observer);

    controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");
    controller->endTrace("test");
    EXPECT_TRUE(observer->calledTraceStarted);
    EXPECT_TRUE(observer->calledTraceEnded);
}

TEST_F(TraceControllerTest, TestCallingAbortTraceCallsObserver) {
    auto observer = std::make_shared<TestTraceEventObserver>();
    const auto controller = std::make_shared<TraceController>(
      PluginRegistry {}, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->addObserver(observer);

    proto::Error error;
    error.set_code(proto::Error_Code_UNDEFINED);
    error.set_description("Undefined");

    controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");
    controller->abortTrace("test", error);
    EXPECT_TRUE(observer->calledTraceStarted);
    EXPECT_TRUE(observer->calledTraceFailed);
    EXPECT_EQ(observer->lastError->code(), error.code());
    EXPECT_EQ(observer->lastError->description(), error.description());
}

TEST_F(TraceControllerTest, TestCallingTimeOutTraceCallsObserver) {
    auto observer = std::make_shared<TestTraceEventObserver>();
    const auto controller = std::make_shared<TraceController>(
      PluginRegistry {}, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->addObserver(observer);

    controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");
    controller->timeoutTrace("test");
    EXPECT_TRUE(observer->calledTraceStarted);
    EXPECT_TRUE(observer->calledTraceFailed);
}

TEST_F(TraceControllerTest, TestCallingEndTraceWithoutStartIsNoOp) {
    auto observer = std::make_shared<TestTraceEventObserver>();
    const auto controller = std::make_shared<TraceController>(
      PluginRegistry {}, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->addObserver(observer);

    controller->endTrace("test");
    EXPECT_FALSE(observer->calledTraceEnded);
}

TEST_F(TraceControllerTest, TestCallingAbortTraceWithoutStartIsNoOp) {
    auto observer = std::make_shared<TestTraceEventObserver>();
    const auto controller = std::make_shared<TraceController>(
      PluginRegistry {}, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->addObserver(observer);

    proto::Error error;
    error.set_code(proto::Error_Code_UNDEFINED);
    error.set_description("Undefined");

    controller->abortTrace("test", error);
    EXPECT_FALSE(observer->calledTraceFailed);
}

TEST_F(TraceControllerTest, TestCallingTimeOutTraceWithoutStartIsNoOp) {
    auto observer = std::make_shared<TestTraceEventObserver>();
    const auto controller = std::make_shared<TraceController>(
      PluginRegistry {}, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->addObserver(observer);

    controller->timeoutTrace("test");
    EXPECT_FALSE(observer->calledTraceFailed);
}

TEST_F(TraceControllerTest, TestCallingStartTraceCallsStartOnPlugins) {
    PluginRegistry registry;
    const auto enabledPlugin = std::make_shared<EnabledPlugin>();
    const auto disabledPlugin = std::make_shared<DisabledPlugin>();

    registry.registerPlugin(enabledPlugin);
    registry.registerPlugin(disabledPlugin);

    const auto controller = std::make_shared<TraceController>(
      registry, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");

    EXPECT_TRUE(enabledPlugin->calledStartWithValidLogger);
    EXPECT_FALSE(disabledPlugin->calledStartWithValidLogger);
}

TEST_F(TraceControllerTest, TestCallingEndTraceCallsEndOnPlugins) {
    PluginRegistry registry;
    const auto enabledPlugin = std::make_shared<EnabledPlugin>();
    const auto disabledPlugin = std::make_shared<DisabledPlugin>();

    registry.registerPlugin(enabledPlugin);
    registry.registerPlugin(disabledPlugin);

    const auto controller = std::make_shared<TraceController>(
      registry, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");
    controller->endTrace("test");

    EXPECT_TRUE(enabledPlugin->calledStartWithValidLogger);
    EXPECT_FALSE(disabledPlugin->calledStartWithValidLogger);
    EXPECT_TRUE(enabledPlugin->calledEndWithValidLogger);
    EXPECT_FALSE(disabledPlugin->calledEndWithValidLogger);
}

TEST_F(TraceControllerTest, TestCallingAbortTraceCallsAbortOnPlugins) {
    PluginRegistry registry;
    const auto enabledPlugin = std::make_shared<EnabledPlugin>();
    const auto disabledPlugin = std::make_shared<DisabledPlugin>();

    registry.registerPlugin(enabledPlugin);
    registry.registerPlugin(disabledPlugin);

    proto::Error error;
    error.set_code(proto::Error_Code_EXCEPTION_RAISED);

    const auto controller = std::make_shared<TraceController>(
      registry, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");
    controller->abortTrace("test", error);

    EXPECT_TRUE(enabledPlugin->calledStartWithValidLogger);
    EXPECT_FALSE(disabledPlugin->calledStartWithValidLogger);
    EXPECT_TRUE(enabledPlugin->calledAbort);
    EXPECT_FALSE(disabledPlugin->calledAbort);
    EXPECT_FALSE(disabledPlugin->calledEndWithValidLogger);
    EXPECT_FALSE(disabledPlugin->calledEndWithValidLogger);

    EXPECT_EQ(enabledPlugin->lastError.code(), proto::Error_Code_EXCEPTION_RAISED);
}

TEST_F(TraceControllerTest, TestCallingTimeOutTraceCallsAbortOnPlugins) {
    PluginRegistry registry;
    const auto enabledPlugin = std::make_shared<EnabledPlugin>();
    const auto disabledPlugin = std::make_shared<DisabledPlugin>();

    registry.registerPlugin(enabledPlugin);
    registry.registerPlugin(disabledPlugin);

    const auto controller = std::make_shared<TraceController>(
      registry, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");
    controller->timeoutTrace("test");

    EXPECT_TRUE(enabledPlugin->calledStartWithValidLogger);
    EXPECT_FALSE(disabledPlugin->calledStartWithValidLogger);
    EXPECT_TRUE(enabledPlugin->calledAbort);
    EXPECT_FALSE(disabledPlugin->calledAbort);
    EXPECT_FALSE(disabledPlugin->calledEndWithValidLogger);
    EXPECT_FALSE(disabledPlugin->calledEndWithValidLogger);

    EXPECT_EQ(enabledPlugin->lastError.code(), proto::Error_Code_TRACE_TIMEOUT);
}

TEST_F(TraceControllerTest, TestRaisingExceptionCallsAbortOnPlugins) {
    PluginRegistry registry;
    const auto enabledPlugin = std::make_shared<EnabledPlugin>();

    registry.registerPlugin(enabledPlugin);
    const auto controller = std::make_shared<TraceController>(
      registry, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");
    SPECTO_TEST_ONLY_HANDLE_CPP_EXCEPTION(
      { throw std::runtime_error("A wild exception appeared"); });

    EXPECT_TRUE(enabledPlugin->calledAbort);
    EXPECT_FALSE(enabledPlugin->calledEndWithValidLogger);
    EXPECT_EQ(enabledPlugin->lastError.code(), proto::Error_Code_EXCEPTION_RAISED);
}

TEST_F(TraceControllerTest, TestRaisingExceptionIsNoOpOnDestructedController) {
    PluginRegistry registry;
    const auto enabledPlugin = std::make_shared<EnabledPlugin>();

    registry.registerPlugin(enabledPlugin);
    auto controller = std::make_shared<TraceController>(
      registry, std::make_shared<TraceBufferConsumer>(), createEmptyAppinfo());
    controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");
    controller = nullptr;
    SPECTO_TEST_ONLY_HANDLE_CPP_EXCEPTION(
      { throw std::runtime_error("A wild exception appeared"); });

    EXPECT_TRUE(enabledPlugin->calledAbort);
    EXPECT_EQ(enabledPlugin->lastError.code(), proto::Error_Code_CONTROLLER_DESTRUCTED);
    EXPECT_FALSE(enabledPlugin->calledEndWithValidLogger);
}

TEST_F(TraceControllerTest, TestControllerDestructorAbortsTrace) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    controller = nullptr;

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, TRACE_FAILURE
    EXPECT_EQ(consumer->entries().size(), 3);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_TRACE_FAILURE);
    EXPECT_EQ(consumer->entries()[2].error().code(), proto::Error_Code_CONTROLLER_DESTRUCTED);
}

TEST_F(TraceControllerTest, TestGlobalConfigurationDisabledAbortsTrace) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");

    const auto configuration = std::make_shared<proto::GlobalConfiguration>();
    configuration->set_enabled(false);
    configuration::setGlobalConfiguration(configuration);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, TRACE_FAILURE
    EXPECT_EQ(consumer->entries().size(), 3);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_TRACE_FAILURE);
    EXPECT_EQ(consumer->entries()[2].error().code(),
              proto::Error_Code_CONFIGURATION_DISABLED_TRACING);
}

TEST_F(TraceControllerTest, TestCallingStartWhileTraceRunningEndsPreviousTrace) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread thread1(consumerThreadFunction, bufferConsumer);
    thread1.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    auto observer = std::make_shared<TestTraceEventObserver>();
    controller->addObserver(observer);

    const auto firstTraceID = controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");
    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }
    EXPECT_TRUE(observer->calledTraceStarted);
    EXPECT_FALSE(observer->calledTraceFailed);
    EXPECT_EQ(observer->lastTraceID, firstTraceID);

    std::thread thread2(consumerThreadFunction, bufferConsumer);
    thread2.detach();
    const auto secondTraceID = controller->startTrace(
      testTraceConfiguration(), std::make_shared<TestTraceConsumer>(), TraceID {}, "test");
    loopExited = false;
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }
    EXPECT_TRUE(observer->calledTraceFailed);
    EXPECT_EQ(observer->lastError->code(), proto::Error_Code_TRACE_LIMIT_EXCEEDED);
    EXPECT_EQ(observer->lastTraceID, secondTraceID);

    std::thread thread3(consumerThreadFunction, bufferConsumer);
    thread3.detach();
    EXPECT_EQ(controller->endTrace("test"), secondTraceID);

    loopExited = false;
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }
    EXPECT_EQ(observer->lastTraceID, secondTraceID);
}

TEST_F(TraceControllerTest, TestCallingStartCallsStartOnConsumer) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    TraceID sessionID;
    const auto traceID =
      controller->startTrace(testTraceConfiguration(), consumer, sessionID, "test");

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_EQ(consumer->id(), traceID);
    EXPECT_EQ(consumer->entries()[0].type(), proto::Entry_Type_TRACE_START);
    EXPECT_EQ(consumer->entries()[0].trace_metadata().session_id(), sessionID.uuid());
    EXPECT_EQ(consumer->entries()[0].group_id(), traceID.uuid());
}

TEST_F(TraceControllerTest, TestCallingEndCallsEndOnConsumer) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    const auto traceID =
      controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    controller->endTrace("test");

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_TRUE(consumer->calledEnd());
    EXPECT_TRUE(consumer->endSuccessful());
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_TRACE_END);
    EXPECT_EQ(consumer->entries()[2].group_id(), traceID.uuid());
}

TEST_F(TraceControllerTest, TestCallingAbortCallsEndOnConsumer) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    const auto traceID =
      controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");

    proto::Error error;
    error.set_code(proto::Error_Code_UNDEFINED);
    error.set_description("Undefined");

    controller->abortTrace("test", error);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_TRUE(consumer->calledEnd());
    EXPECT_FALSE(consumer->endSuccessful());
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_TRACE_FAILURE);
    EXPECT_EQ(consumer->entries()[2].group_id(), traceID.uuid());
}

TEST_F(TraceControllerTest, TestCallingTimeoutCallsEndOnConsumer) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    const auto traceID =
      controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    controller->timeoutTrace("test");

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_TRUE(consumer->calledEnd());
    EXPECT_FALSE(consumer->endSuccessful());
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_TRACE_FAILURE);
    EXPECT_EQ(consumer->entries()[2].group_id(), traceID.uuid());
}

TEST_F(TraceControllerTest, TestConsumerReceivesLoggedEntries) {
    PluginRegistry registry;
    const auto writerPlugin = std::make_shared<WriterPlugin>();

    registry.registerPlugin(writerPlugin);

    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(registry, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    const auto traceID =
      controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    controller->endTrace("test");

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_EQ(consumer->entries()[0].type(), proto::Entry_Type_TRACE_START);
    EXPECT_EQ(consumer->entries()[0].group_id(), traceID.uuid());
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_TASK_CALL);
    EXPECT_EQ(consumer->entries()[3].type(), proto::Entry_Type_BACKTRACE);
    EXPECT_EQ(consumer->entries()[4].type(), proto::Entry_Type_TRACE_END);
    EXPECT_EQ(consumer->entries()[4].group_id(), traceID.uuid());
}

TEST_F(TraceControllerTest, TestCompleteMultipleTraces) {
    PluginRegistry registry;
    const auto writerPlugin = std::make_shared<WriterPlugin>();

    registry.registerPlugin(writerPlugin);

    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(registry, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    const auto trace1ID =
      controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    controller->endTrace("test");
    const auto trace2ID =
      controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    controller->endTrace("test");

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_EQ(consumer->entries()[0].type(), proto::Entry_Type_TRACE_START);
    EXPECT_EQ(consumer->entries()[0].group_id(), trace1ID.uuid());
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_TASK_CALL);
    EXPECT_EQ(consumer->entries()[3].type(), proto::Entry_Type_BACKTRACE);
    EXPECT_EQ(consumer->entries()[4].type(), proto::Entry_Type_TRACE_END);
    EXPECT_EQ(consumer->entries()[4].group_id(), trace1ID.uuid());

    EXPECT_EQ(consumer->entries()[5].type(), proto::Entry_Type_TRACE_START);
    EXPECT_EQ(consumer->entries()[5].group_id(), trace2ID.uuid());
    EXPECT_EQ(consumer->entries()[7].type(), proto::Entry_Type_TASK_CALL);
    EXPECT_EQ(consumer->entries()[8].type(), proto::Entry_Type_BACKTRACE);
    EXPECT_EQ(consumer->entries()[9].type(), proto::Entry_Type_TRACE_END);
    EXPECT_EQ(consumer->entries()[9].group_id(), trace2ID.uuid());
}

TEST_F(TraceControllerTest, TestConsumerReceivesAnnotations) {
    PluginRegistry registry;
    const auto writerPlugin = std::make_shared<WriterPlugin>();

    registry.registerPlugin(writerPlugin);

    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(registry, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    const auto traceID =
      controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto annotationID = controller->annotateTrace("test", "test_key", "test_value");
    controller->endTrace("test");

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_EQ(consumer->entries()[0].type(), proto::Entry_Type_TRACE_START);
    EXPECT_EQ(consumer->entries()[0].group_id(), traceID.uuid());
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_TASK_CALL);
    EXPECT_EQ(consumer->entries()[3].type(), proto::Entry_Type_TRACE_ANNOTATION);
    EXPECT_EQ(consumer->entries()[3].annotation().id(), annotationID);
    EXPECT_EQ(consumer->entries()[3].annotation().key(), "test_key");
    EXPECT_EQ(consumer->entries()[3].annotation().value(), "test_value");
    EXPECT_EQ(consumer->entries()[4].type(), proto::Entry_Type_BACKTRACE);
    EXPECT_EQ(consumer->entries()[5].type(), proto::Entry_Type_TRACE_END);
    EXPECT_EQ(consumer->entries()[5].group_id(), traceID.uuid());
}

TEST_F(TraceControllerTest, TestConsecutiveTraceAnnotationsHaveIncreasingIDs) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto annotationID1 = controller->annotateTrace("test", "key1", "value1");
    const auto annotationID2 = controller->annotateTrace("test", "key2", "value2");
    EXPECT_GT(annotationID2, annotationID1);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, TRACE_ANNOTATION, TRACE_ANNOTATION
    EXPECT_EQ(consumer->entries().size(), 4);

    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_TRACE_ANNOTATION);
    EXPECT_EQ(consumer->entries()[2].annotation().id(), annotationID1);
    EXPECT_EQ(consumer->entries()[2].annotation().key(), "key1");
    EXPECT_EQ(consumer->entries()[2].annotation().value(), "value1");

    EXPECT_EQ(consumer->entries()[3].type(), proto::Entry_Type_TRACE_ANNOTATION);
    EXPECT_EQ(consumer->entries()[3].annotation().id(), annotationID2);
    EXPECT_EQ(consumer->entries()[3].annotation().key(), "key2");
    EXPECT_EQ(consumer->entries()[3].annotation().value(), "value2");
}

TEST_F(TraceControllerTest, TestConsecutiveTracesResetTraceAnnotationIDs) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer1 = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer1, TraceID {}, "test");
    const auto annotationID1 = controller->annotateTrace("test", "key1", "value1");
    controller->endTrace("test");

    const auto consumer2 = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer2, TraceID {}, "test");
    const auto annotationID2 = controller->annotateTrace("test", "key2", "value2");
    controller->endTrace("test");

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, TRACE_ANNOTATION, TRACE_END
    EXPECT_EQ(consumer1->entries().size(), 4);
    EXPECT_EQ(consumer1->entries()[2].type(), proto::Entry_Type_TRACE_ANNOTATION);
    EXPECT_EQ(consumer1->entries()[2].annotation().id(), annotationID1);
    EXPECT_EQ(consumer1->entries()[2].annotation().key(), "key1");
    EXPECT_EQ(consumer1->entries()[2].annotation().value(), "value1");

    // TRACE_START, APP_INFO, TRACE_ANNOTATION, TRACE_END
    EXPECT_EQ(consumer2->entries().size(), 4);
    EXPECT_EQ(consumer2->entries()[2].type(), proto::Entry_Type_TRACE_ANNOTATION);
    EXPECT_EQ(consumer2->entries()[2].annotation().id(), annotationID2);
    EXPECT_EQ(consumer2->entries()[2].annotation().key(), "key2");
    EXPECT_EQ(consumer2->entries()[2].annotation().value(), "value2");
}

TEST_F(TraceControllerTest, TestAnnotatingTraceWithNoActiveTraceIsNoOp) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->annotateTrace("test", "key1", "value1");

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_TRUE(consumer->entries().empty());
}

TEST_F(TraceControllerTest, TestStartSpan) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto spanID = controller->startSpan("span");

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START
    EXPECT_EQ(consumer->entries().size(), 3);
    const auto spanStart = consumer->entries()[2];
    EXPECT_EQ(spanStart.type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(spanStart.group_id(), spanID.uuid());
    EXPECT_EQ(spanStart.span_metadata().name(), "span");
}

TEST_F(TraceControllerTest, TestStartSpanGeneratesDifferentConsecutiveSpanIDs) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto span1 = controller->startSpan("span1");
    const auto span2 = controller->startSpan("span2");

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_START
    EXPECT_EQ(consumer->entries().size(), 4);
    const auto spanStart1 = consumer->entries()[2];
    EXPECT_EQ(spanStart1.type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(spanStart1.span_metadata().name(), "span1");
    EXPECT_EQ(span1.uuid(), spanStart1.group_id());

    const auto spanStart2 = consumer->entries()[3];
    EXPECT_EQ(spanStart2.type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(spanStart2.span_metadata().name(), "span2");
    EXPECT_EQ(span2.uuid(), spanStart2.group_id());

    EXPECT_NE(spanStart1.group_id(), spanStart2.group_id());
}

TEST_F(TraceControllerTest, TestEndSpanWithID) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto spanID = controller->startSpan("span");
    EXPECT_TRUE(controller->endSpan(spanID));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_END
    EXPECT_EQ(consumer->entries().size(), 4);
    const auto spanEnd = consumer->entries()[3];
    EXPECT_EQ(spanEnd.type(), proto::Entry_Type_SPAN_END);
    EXPECT_EQ(spanEnd.group_id(), spanID.uuid());
}

TEST_F(TraceControllerTest, TestEndSpanWithIDNoSpans) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    EXPECT_FALSE(controller->endSpan(TraceID {}));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO
    EXPECT_EQ(consumer->entries().size(), 2);
}

TEST_F(TraceControllerTest, TestEndSpanWithIDNonexistentSpan) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    controller->startSpan("span");
    EXPECT_FALSE(controller->endSpan(TraceID {}));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START
    EXPECT_EQ(consumer->entries().size(), 3);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_SPAN_START);
}

TEST_F(TraceControllerTest, TestEndSpanWithIDNoTrace) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    EXPECT_FALSE(controller->endSpan(TraceID {}));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_TRUE(consumer->entries().empty());
}

TEST_F(TraceControllerTest, TestEndSpanWithName) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto spanID = controller->startSpan("span");
    EXPECT_EQ(controller->endSpan("span"), spanID);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_END
    EXPECT_EQ(consumer->entries().size(), 4);
    const auto spanEnd = consumer->entries()[3];
    EXPECT_EQ(spanEnd.type(), proto::Entry_Type_SPAN_END);
    EXPECT_EQ(spanEnd.group_id(), spanID.uuid());
}

TEST_F(TraceControllerTest, TestEndSpanWithNameNoSpans) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    EXPECT_EQ(controller->endSpan("span"), TraceID::empty);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO
    EXPECT_EQ(consumer->entries().size(), 2);
}

TEST_F(TraceControllerTest, TestEndSpanWithNameNonexistentSpan) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    controller->startSpan("span");
    EXPECT_EQ(controller->endSpan("other span"), TraceID::empty);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START
    EXPECT_EQ(consumer->entries().size(), 3);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_SPAN_START);
}

TEST_F(TraceControllerTest, TestEndSpanWithNameNoTrace) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    EXPECT_EQ(controller->endSpan("other span"), TraceID::empty);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_TRUE(consumer->entries().empty());
}

TEST_F(TraceControllerTest, TestEndParentSpanDoesNotEndChildSpans) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto rootSpanID = controller->startSpan("span");
    const auto childSpan1ID = controller->startSpan("child span 1");
    const auto childSpan2ID = controller->startSpan("child span 2");

    EXPECT_TRUE(controller->endSpan(childSpan1ID));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_START, SPAN_START, SPAN_END
    EXPECT_EQ(consumer->entries().size(), 6);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[2].group_id(), rootSpanID.uuid());
    EXPECT_EQ(consumer->entries()[3].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[3].group_id(), childSpan1ID.uuid());
    EXPECT_EQ(consumer->entries()[4].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[4].group_id(), childSpan2ID.uuid());

    const auto spanEndChild1 = consumer->entries()[5];
    EXPECT_EQ(spanEndChild1.type(), proto::Entry_Type_SPAN_END);
    EXPECT_EQ(spanEndChild1.group_id(), childSpan1ID.uuid());
}

TEST_F(TraceControllerTest, TestEndSpanWithSameNamesEndsTopmost) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto rootSpanID = controller->startSpan("span");
    const auto childSpan1ID = controller->startSpan("child span");
    const auto childSpan2ID = controller->startSpan("child span");

    EXPECT_EQ(controller->endSpan("child span"), childSpan2ID);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_START, SPAN_START, SPAN_END
    EXPECT_EQ(consumer->entries().size(), 6);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[2].group_id(), rootSpanID.uuid());
    EXPECT_EQ(consumer->entries()[3].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[3].group_id(), childSpan1ID.uuid());
    EXPECT_EQ(consumer->entries()[4].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[4].group_id(), childSpan2ID.uuid());
    EXPECT_EQ(consumer->entries()[5].type(), proto::Entry_Type_SPAN_END);
    EXPECT_EQ(consumer->entries()[5].group_id(), childSpan2ID.uuid());
}

TEST_F(TraceControllerTest, TestEndSameSpanTwice) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto rootSpanID = controller->startSpan("span");
    const auto childSpanID = controller->startSpan("child span");

    EXPECT_TRUE(controller->endSpan(childSpanID));
    EXPECT_FALSE(controller->endSpan(childSpanID));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_START, SPAN_END
    EXPECT_EQ(consumer->entries().size(), 5);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[2].group_id(), rootSpanID.uuid());
    EXPECT_EQ(consumer->entries()[3].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[3].group_id(), childSpanID.uuid());
    EXPECT_EQ(consumer->entries()[4].type(), proto::Entry_Type_SPAN_END);
    EXPECT_EQ(consumer->entries()[4].group_id(), childSpanID.uuid());
}

TEST_F(TraceControllerTest, TestAnnotateSpanWithID) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto spanID = controller->startSpan("span");
    EXPECT_EQ(controller->annotateSpan(spanID, "key", "value"), 1);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_ANNOTATION
    EXPECT_EQ(consumer->entries().size(), 4);
    const auto spanAnnotation = consumer->entries()[3];
    EXPECT_EQ(spanAnnotation.type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(spanAnnotation.group_id(), spanID.uuid());
    EXPECT_EQ(spanAnnotation.annotation().key(), "key");
    EXPECT_EQ(spanAnnotation.annotation().value(), "value");
}

TEST_F(TraceControllerTest, TestAnnotateSpanWithIDNoSpans) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    EXPECT_EQ(controller->annotateSpan(TraceID {}, "key", "value"), EmptyAnnotationID);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO
    EXPECT_EQ(consumer->entries().size(), 2);
}

TEST_F(TraceControllerTest, TestAnnotateSpanWithIDNonexistentSpan) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    controller->startSpan("span");
    EXPECT_EQ(controller->annotateSpan(TraceID {}, "key", "value"), EmptyAnnotationID);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START
    EXPECT_EQ(consumer->entries().size(), 3);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_SPAN_START);
}

TEST_F(TraceControllerTest, TestAnnotateSpanWithIDNoTrace) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    EXPECT_EQ(controller->annotateSpan(TraceID {}, "key", "value"), EmptyAnnotationID);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_TRUE(consumer->entries().empty());
}

TEST_F(TraceControllerTest, TestAnnotateSpanWithName) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto spanID = controller->startSpan("span");
    EXPECT_EQ(controller->annotateSpan("span", "key", "value"),
              std::make_pair(spanID, static_cast<std::uint64_t>(1)));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_ANNOTATION
    EXPECT_EQ(consumer->entries().size(), 4);
    const auto spanAnnotation = consumer->entries()[3];
    EXPECT_EQ(spanAnnotation.type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(spanAnnotation.group_id(), spanID.uuid());
    EXPECT_EQ(spanAnnotation.annotation().key(), "key");
    EXPECT_EQ(spanAnnotation.annotation().value(), "value");
}

TEST_F(TraceControllerTest, TestAnnotateSpanWithNameNoSpans) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    EXPECT_EQ(controller->annotateSpan("span", "key", "value"),
              std::make_pair(TraceID::empty, EmptyAnnotationID));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO
    EXPECT_EQ(consumer->entries().size(), 2);
}

TEST_F(TraceControllerTest, TestAnnotateSpanWithNameNonexistentSpan) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    controller->startSpan("span");
    EXPECT_EQ(controller->annotateSpan("other span", "key", "value"),
              std::make_pair(TraceID::empty, EmptyAnnotationID));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START
    EXPECT_EQ(consumer->entries().size(), 3);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_SPAN_START);
}

TEST_F(TraceControllerTest, TestAnnotateSpanWithNameNoTrace) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    EXPECT_EQ(controller->annotateSpan("other span", "key", "value"),
              std::make_pair(TraceID::empty, EmptyAnnotationID));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    EXPECT_TRUE(consumer->entries().empty());
}

TEST_F(TraceControllerTest, TestAnnotateSpanWithSameNamesAnnotatesTopmost) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto rootSpanID = controller->startSpan("span");
    const auto childSpan1ID = controller->startSpan("child span");
    const auto childSpan2ID = controller->startSpan("child span");

    EXPECT_EQ(controller->annotateSpan("child span", "key", "value"),
              std::make_pair(childSpan2ID, static_cast<std::uint64_t>(1)));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_START, SPAN_START, SPAN_ANNOTATION
    EXPECT_EQ(consumer->entries().size(), 6);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[2].group_id(), rootSpanID.uuid());
    EXPECT_EQ(consumer->entries()[3].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[3].group_id(), childSpan1ID.uuid());
    EXPECT_EQ(consumer->entries()[4].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[4].group_id(), childSpan2ID.uuid());

    const auto spanAnnotation = consumer->entries()[5];
    EXPECT_EQ(spanAnnotation.type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(spanAnnotation.group_id(), childSpan2ID.uuid());
    EXPECT_EQ(spanAnnotation.annotation().key(), "key");
    EXPECT_EQ(spanAnnotation.annotation().value(), "value");
}

TEST_F(TraceControllerTest, TestAnnotateSpanAfterEndingSpan) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto spanID = controller->startSpan("span");
    EXPECT_TRUE(controller->endSpan(spanID));
    EXPECT_EQ(controller->annotateSpan(spanID, "key", "value"), EmptyAnnotationID);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_END
    EXPECT_EQ(consumer->entries().size(), 4);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[2].group_id(), spanID.uuid());
    EXPECT_EQ(consumer->entries()[3].type(), proto::Entry_Type_SPAN_END);
    EXPECT_EQ(consumer->entries()[3].group_id(), spanID.uuid());
}

TEST_F(TraceControllerTest, TestMultipleAnnotationsOnSameSpan) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto spanID = controller->startSpan("span");
    EXPECT_EQ(controller->annotateSpan(spanID, "key1", "value1"), 1);
    EXPECT_EQ(controller->annotateSpan(spanID, "key2", "value2"), 2);

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_ANNOTATION, SPAN_ANNOTATION
    EXPECT_EQ(consumer->entries().size(), 5);

    const auto spanAnnotation1 = consumer->entries()[3];
    EXPECT_EQ(spanAnnotation1.type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(spanAnnotation1.group_id(), spanID.uuid());
    EXPECT_EQ(spanAnnotation1.annotation().key(), "key1");
    EXPECT_EQ(spanAnnotation1.annotation().value(), "value1");

    const auto spanAnnotation2 = consumer->entries()[4];
    EXPECT_EQ(spanAnnotation2.type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(spanAnnotation2.group_id(), spanID.uuid());
    EXPECT_EQ(spanAnnotation2.annotation().key(), "key2");
    EXPECT_EQ(spanAnnotation2.annotation().value(), "value2");
}

TEST_F(TraceControllerTest, TestAdjacentSpansWithAnnotations) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");

    const auto span1ID = controller->startSpan("span1");
    EXPECT_EQ(controller->annotateSpan(span1ID, "key1", "value1"), 1);
    EXPECT_TRUE(controller->endSpan(span1ID));

    const auto span2ID = controller->startSpan("span2");
    EXPECT_EQ(controller->annotateSpan(span2ID, "key2", "value2"), 2);
    EXPECT_TRUE(controller->endSpan(span2ID));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_ANNOTATION, SPAN_END, SPAN_START,
    // SPAN_ANNOTATION, SPAN_END
    EXPECT_EQ(consumer->entries().size(), 8);

    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[2].group_id(), span1ID.uuid());

    const auto spanAnnotation1 = consumer->entries()[3];
    EXPECT_EQ(spanAnnotation1.type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(spanAnnotation1.group_id(), span1ID.uuid());
    EXPECT_EQ(spanAnnotation1.annotation().key(), "key1");
    EXPECT_EQ(spanAnnotation1.annotation().value(), "value1");

    const auto spanEnd1 = consumer->entries()[4];
    EXPECT_EQ(spanEnd1.type(), proto::Entry_Type_SPAN_END);
    EXPECT_EQ(spanEnd1.group_id(), span1ID.uuid());

    EXPECT_EQ(consumer->entries()[5].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[5].group_id(), span2ID.uuid());

    const auto spanAnnotation2 = consumer->entries()[6];
    EXPECT_EQ(spanAnnotation2.type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(spanAnnotation2.group_id(), span2ID.uuid());
    EXPECT_EQ(spanAnnotation2.annotation().key(), "key2");
    EXPECT_EQ(spanAnnotation2.annotation().value(), "value2");

    const auto spanEnd2 = consumer->entries()[7];
    EXPECT_EQ(spanEnd2.type(), proto::Entry_Type_SPAN_END);
    EXPECT_EQ(spanEnd2.group_id(), span2ID.uuid());
}

TEST_F(TraceControllerTest, TestNestedSpansWithAnnotations) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");

    const auto span1ID = controller->startSpan("span1");
    EXPECT_EQ(controller->annotateSpan(span1ID, "key1", "value1"), 1);

    const auto span2ID = controller->startSpan("span2");
    const auto span3ID = controller->startSpan("span3");

    EXPECT_EQ(controller->annotateSpan(span2ID, "key2", "value2"), 2);
    EXPECT_EQ(controller->annotateSpan(span3ID, "key3", "value3"), 3);

    EXPECT_TRUE(controller->endSpan(span3ID));
    EXPECT_TRUE(controller->endSpan(span2ID));
    EXPECT_TRUE(controller->endSpan(span1ID));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_ANNOTATION, SPAN_START, SPAN_START
    // SPAN_ANNOTATION, SPAN_ANNOTATION, SPAN_END, SPAN_END, SPAN_END
    EXPECT_EQ(consumer->entries().size(), 11);

    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[2].group_id(), span1ID.uuid());

    const auto spanAnnotation1 = consumer->entries()[3];
    EXPECT_EQ(spanAnnotation1.type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(spanAnnotation1.group_id(), span1ID.uuid());
    EXPECT_EQ(spanAnnotation1.annotation().key(), "key1");
    EXPECT_EQ(spanAnnotation1.annotation().value(), "value1");

    EXPECT_EQ(consumer->entries()[4].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[4].group_id(), span2ID.uuid());

    EXPECT_EQ(consumer->entries()[5].type(), proto::Entry_Type_SPAN_START);
    EXPECT_EQ(consumer->entries()[5].group_id(), span3ID.uuid());

    const auto spanAnnotation2 = consumer->entries()[6];
    EXPECT_EQ(spanAnnotation2.type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(spanAnnotation2.group_id(), span2ID.uuid());
    EXPECT_EQ(spanAnnotation2.annotation().key(), "key2");
    EXPECT_EQ(spanAnnotation2.annotation().value(), "value2");

    const auto spanAnnotation3 = consumer->entries()[7];
    EXPECT_EQ(spanAnnotation3.type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(spanAnnotation3.group_id(), span3ID.uuid());
    EXPECT_EQ(spanAnnotation3.annotation().key(), "key3");
    EXPECT_EQ(spanAnnotation3.annotation().value(), "value3");

    const auto spanEnd3 = consumer->entries()[8];
    EXPECT_EQ(spanEnd3.type(), proto::Entry_Type_SPAN_END);
    EXPECT_EQ(spanEnd3.group_id(), span3ID.uuid());

    const auto spanEnd2 = consumer->entries()[9];
    EXPECT_EQ(spanEnd2.type(), proto::Entry_Type_SPAN_END);
    EXPECT_EQ(spanEnd2.group_id(), span2ID.uuid());

    const auto spanEnd1 = consumer->entries()[10];
    EXPECT_EQ(spanEnd1.type(), proto::Entry_Type_SPAN_END);
    EXPECT_EQ(spanEnd1.group_id(), span1ID.uuid());
}

TEST_F(TraceControllerTest, TestConsecutiveSpanAnnotationsHaveIncreasingIDs) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    const auto spanID = controller->startSpan("span");
    EXPECT_EQ(controller->annotateSpan("span", "key1", "value1"),
              std::make_pair(spanID, static_cast<std::uint64_t>(1)));
    EXPECT_EQ(controller->annotateSpan("span", "key2", "value2"),
              std::make_pair(spanID, static_cast<std::uint64_t>(2)));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_ANNOTATION, SPAN_ANNOTATION
    EXPECT_EQ(consumer->entries().size(), 5);

    EXPECT_EQ(consumer->entries()[3].type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(consumer->entries()[3].annotation().id(), 1);
    EXPECT_EQ(consumer->entries()[3].annotation().key(), "key1");
    EXPECT_EQ(consumer->entries()[3].annotation().value(), "value1");

    EXPECT_EQ(consumer->entries()[4].type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(consumer->entries()[4].annotation().id(), 2);
    EXPECT_EQ(consumer->entries()[4].annotation().key(), "key2");
    EXPECT_EQ(consumer->entries()[4].annotation().value(), "value2");
}

TEST_F(TraceControllerTest, TestConsecutiveTracesResetSpanAnnotationIDs) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer1 = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer1, TraceID {}, "test");
    const auto spanID1 = controller->startSpan("span");
    EXPECT_EQ(controller->annotateSpan("span", "key1", "value1"),
              std::make_pair(spanID1, static_cast<std::uint64_t>(1)));
    controller->endTrace("test");

    const auto consumer2 = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer2, TraceID {}, "test");
    const auto spanID2 = controller->startSpan("span");
    EXPECT_EQ(controller->annotateSpan("span", "key2", "value2"),
              std::make_pair(spanID2, static_cast<std::uint64_t>(1)));
    controller->endTrace("test");

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, SPAN_START, SPAN_ANNOTATION, TRACE_END
    EXPECT_EQ(consumer1->entries().size(), 5);
    EXPECT_EQ(consumer1->entries()[3].type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(consumer1->entries()[3].annotation().id(), 1);
    EXPECT_EQ(consumer1->entries()[3].annotation().key(), "key1");
    EXPECT_EQ(consumer1->entries()[3].annotation().value(), "value1");

    // TRACE_START, APP_INFO, SPAN_START, SPAN_ANNOTATION, TRACE_END
    EXPECT_EQ(consumer2->entries().size(), 5);
    EXPECT_EQ(consumer2->entries()[3].type(), proto::Entry_Type_SPAN_ANNOTATION);
    EXPECT_EQ(consumer2->entries()[3].annotation().id(), 1);
    EXPECT_EQ(consumer2->entries()[3].annotation().key(), "key2");
    EXPECT_EQ(consumer2->entries()[3].annotation().value(), "value2");
}

TEST_F(TraceControllerTest, TestLogEntry) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());

    const auto consumer = std::make_shared<TestTraceConsumer>();
    controller->startTrace(testTraceConfiguration(), consumer, TraceID {}, "test");
    controller->log(protobuf::makeEntry(proto::Entry_Type_TOTAL_STARTUP_TIME));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }

    // TRACE_START, APP_INFO, TOTAL_STARTUP_TIME
    EXPECT_EQ(consumer->entries().size(), 3);
    EXPECT_EQ(consumer->entries()[2].type(), proto::Entry_Type_TOTAL_STARTUP_TIME);
}

TEST_F(TraceControllerTest, TestLogEntryWhenNoTraceRunning) {
    const auto bufferConsumer = std::make_shared<TraceBufferConsumer>();
    std::thread consumerThread(consumerThreadFunction, bufferConsumer);
    consumerThread.detach();

    const auto controller =
      std::make_shared<TraceController>(PluginRegistry {}, bufferConsumer, createEmptyAppinfo());
    controller->log(protobuf::makeEntry(proto::Entry_Type_TOTAL_STARTUP_TIME));

    std::atomic_bool loopExited {false};
    bufferConsumer->stopLoop([&loopExited]() { loopExited = true; });
    while (!loopExited) {
    }
}
