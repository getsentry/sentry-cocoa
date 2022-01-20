// Copyright (c) Specto Inc. All rights reserved.

#include "LogProcessor.h"

#include "Filesystem.h"
#include "LZ4Stream.h"
#include "ScopeGuard.h"
#include "fmt/format.h"

#include <fstream>

namespace specto {

LogProcessor::LogProcessor(filesystem::Path logPath) : logPath_(std::move(logPath)) {
    const auto regexFmt = fmt::format(
      "{}/{}.[0-9].{}", logPath_.parentPath().string(), logPath_.stem(), logPath_.extension());
    rotatingLogFileNameRegex_ = std::regex(regexFmt);
}

bool LogProcessor::createCompressedLogFile(const filesystem::Path &outputPath) const {
    const auto logDirPath = logPath_.parentPath();
    std::vector<filesystem::Path> rotatingLogPaths;
    filesystem::forEachInDirectory(
      logDirPath, [&regex = rotatingLogFileNameRegex_, &rotatingLogPaths](auto path) {
          if (std::regex_match(path.string(), regex)) {
              rotatingLogPaths.push_back(std::move(path));
          }
      });
    // Sort filenames in descending order (the older logs have a higher number)
    std::sort(rotatingLogPaths.begin(),
              rotatingLogPaths.end(),
              [](const auto &pathA, const auto &pathB) { return pathB.string() < pathA.string(); });

    // Write all of the log files to an LZ4-compressed stream.
    std::ofstream outputStream(outputPath.string());
    if (!outputStream) {
        return false;
    }
    SPECTO_DEFER(outputStream.close());

    lz4_stream::ostream lz4Stream(outputStream);
    if (!lz4Stream) {
        return false;
    }
    SPECTO_DEFER(lz4Stream.close());

    for (const auto &path : rotatingLogPaths) {
        std::ifstream inputStream(path.string());
        if (!inputStream) {
            // Skip any failed rotating log file reads rather than aborting
            // the entire operation.
            continue;
        }
        SPECTO_DEFER(inputStream.close());
        lz4Stream << inputStream.rdbuf() << '\n';
        if (!lz4Stream || !outputStream) {
            return false;
        }
    }
    std::ifstream activeLogInputStream(logPath_.string());
    if (!activeLogInputStream) {
        return false;
    }
    SPECTO_DEFER(activeLogInputStream.close());
    lz4Stream << activeLogInputStream.rdbuf() << '\n';
    if (!lz4Stream || !outputStream) {
        return false;
    }

    // Delete the rotating log files.
    for (const auto &path : rotatingLogPaths) {
        filesystem::remove(path);
    }
    return true;
}
} // namespace specto
