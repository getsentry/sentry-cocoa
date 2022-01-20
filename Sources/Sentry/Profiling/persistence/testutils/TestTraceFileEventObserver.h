// Copyright (c) Specto Inc. All rights reserved.

#include "cpp/persistence/src/TraceFileEventObserver.h"

namespace specto {
namespace test {
class TestTraceFileEventObserver : public TraceFileEventObserver {
public:
    void traceFileCompleted(const filesystem::Path &oldPath,
                            const filesystem::Path &newPath) override;
    void traceFileUploadQueued(const filesystem::Path &oldPath,
                               const filesystem::Path &newPath) override;
    void traceFileUploadCancelled(const filesystem::Path &oldPath,
                                  const filesystem::Path &newPath) override;
    void traceFileUploadFinished(const filesystem::Path &oldPath) override;
    void traceFilePruned(const filesystem::Path &path) override;

    bool calledTraceFileCompleted = false;
    bool calledTraceFileUploadQueued = false;
    bool calledTraceFileUploadCancelled = false;
    bool calledTraceFileUploadFinished = false;
    bool calledTraceFilePruned = false;
    filesystem::Path lastOldPath;
    filesystem::Path lastNewPath;
};
} // namespace test
} // namespace specto
