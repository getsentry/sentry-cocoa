// Copyright (c) Specto Inc. All rights reserved.

#import <memory>

namespace specto {
class TraceConsumer;
class TraceFileManager;

/**
 * Creates a new trace consumer using the default configuration for iOS trace consumers,
 * which writes to a file managed by the specified file manager, and also logs the entries
 * to the console.
 */
std::shared_ptr<specto::TraceConsumer>
  traceConsumerForFileManager(std::shared_ptr<TraceFileManager> fileManager, bool synchronous);

} // namespace specto
