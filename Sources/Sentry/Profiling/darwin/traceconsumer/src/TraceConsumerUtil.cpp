// Copyright (c) Specto Inc. All rights reserved.

#include "TraceConsumerUtil.h"

#include "cpp/log/src/Log.h"
#include "cpp/persistence/src/TraceFileManager.h"
#include "cpp/trace/src/TraceConsumer.h"
#include "cpp/trace/src/TraceConsumerMultiProxy.h"
#include "cpp/traceconsumers/tracefile/src/TraceFileTraceConsumer.h"

using namespace specto;

namespace specto {

std::shared_ptr<TraceConsumer>
  traceConsumerForFileManager(std::shared_ptr<TraceFileManager> fileManager, bool synchronous) {
    const auto proxy = std::make_shared<TraceConsumerMultiProxy>();
    if (fileManager != nullptr) {
        proxy->addConsumer(
          std::make_shared<TraceFileTraceConsumer>(std::move(fileManager), synchronous));
    } else {
        SPECTO_LOG_ERROR("fileManager is null, not going to create TraceFileTraceConsumer");
    }
    return proxy;
}

} // namespace specto
