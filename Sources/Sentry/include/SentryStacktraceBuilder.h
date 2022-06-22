#import "SentryCrashMachineContext.h"
#include "SentryCrashThread.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>
#import "SentryCrashStackCursor.h"

@class SentryStacktrace, SentryFrameRemover, SentryCrashStackEntryMapper;

NS_ASSUME_NONNULL_BEGIN

/** Uses SentryCrash internally to retrieve the stacktrace.
 */
@interface SentryStacktraceBuilder : NSObject
SENTRY_NO_INIT

- (id)initWithCrashStackEntryMapper:(SentryCrashStackEntryMapper *)crashStackEntryMapper;


/**
 * Copies the stack entries from a thread to the especified buffer up to the max entries and return the number of entries found.
 */
- (unsigned int)getStackEntriesFromThread:(SentryCrashThread)thread context:(struct SentryCrashMachineContext *)context buffer:(SentryCrashStackEntry *)buffer maxEntries:(unsigned int)amount;

/**
 * Builds the stacktrace for the current thread removing frames from the SentrySDK until frames from
 * a different package are found. When including Sentry via the Swift Package Manager the package is
 * the same as the application that includes Sentry. In this case the full stacktrace is returned
 * without skipping frames.
 */
- (SentryStacktrace *)buildStacktraceForCurrentThread;

/**
 * Builds the stacktrace for given thread removing frames from the SentrySDK until frames from
 * a different package are found. When including Sentry via the Swift Package Manager the package is
 * the same as the application that includes Sentry. In this case the full stacktrace is returned
 * without skipping frames.
 */
- (SentryStacktrace *)buildStacktraceForThread:(SentryCrashThread)thread
                                       context:(struct SentryCrashMachineContext *)context;


- (SentryStacktrace *)buildStackTraceFromStackEntries:(SentryCrashStackEntry *)entries amount:(unsigned int)amount;
@end

NS_ASSUME_NONNULL_END
