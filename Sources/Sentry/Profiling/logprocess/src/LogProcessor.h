// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "Path.h"

#include <regex>

namespace specto {

/**
 * Concatenates and compresses log files in preparation for upload to the diagnostics
 * service.
 */
class LogProcessor {
public:
    /**
     * Initializes a new `LogProcessor` instance.
     * @param logPath The path to the active log file.
     */
    explicit LogProcessor(filesystem::Path logPath);

    /**
     * Concatenates any existing rotating log files with the current contents of the
     * active log file and creates a compressed archive. The rotating log files will
     * be deleted at the end of the operation, but the active log file will be unaffected.
     * @param outputPath The path to write the compressed archive to.
     * @return Whether the operation was successful.
     */
    bool createCompressedLogFile(const filesystem::Path &outputPath) const;

private:
    filesystem::Path logPath_;
    std::regex rotatingLogFileNameRegex_;
};

} // namespace specto
