#import "SentryBacktrace.hpp"
#import "SentryProfilerState.h"

/*
 * This extension defines C++ interface on SentryProfilerState that is not able to be imported into
 * a bridging header via SentryProfilerState.h due to C++/Swift interop limitations.
 */

@interface
SentryProfilerState ()

- (void)appendBacktrace:(const sentry::profiling::Backtrace &)backtrace;

@end
