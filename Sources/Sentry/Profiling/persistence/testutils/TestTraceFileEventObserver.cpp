// Copyright (c) Specto Inc. All rights reserved.

#include "TestTraceFileEventObserver.h"

namespace specto::test {

void TestTraceFileEventObserver::traceFileCompleted(const filesystem::Path &oldPath,
                                                    const filesystem::Path &newPath) {
    calledTraceFileCompleted = true;
    lastOldPath = oldPath;
    lastNewPath = newPath;
}

void TestTraceFileEventObserver::traceFileUploadQueued(const filesystem::Path &oldPath,
                                                       const filesystem::Path &newPath) {
    calledTraceFileUploadQueued = true;
    lastOldPath = oldPath;
    lastNewPath = newPath;
}

void TestTraceFileEventObserver::traceFileUploadCancelled(const filesystem::Path &oldPath,
                                                          const filesystem::Path &newPath) {
    calledTraceFileUploadCancelled = true;
    lastOldPath = oldPath;
    lastNewPath = newPath;
}

void TestTraceFileEventObserver::traceFileUploadFinished(const filesystem::Path &oldPath) {
    calledTraceFileUploadFinished = true;
    lastOldPath = oldPath;
    lastNewPath = filesystem::Path("");
}

void TestTraceFileEventObserver::traceFilePruned(const filesystem::Path &oldPath) {
    calledTraceFilePruned = true;
    lastOldPath = oldPath;
    lastNewPath = filesystem::Path("");
}

} // namespace specto::test
