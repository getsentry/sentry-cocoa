#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryCrashStackEntryMapper;
@class SentryStacktrace;
@class SentryFrame;

NS_ASSUME_NONNULL_BEGIN

/** Uses KSCrash internally to retrieve the stacktrace.
 */
@interface SentryStacktraceBuilder : NSObject
SENTRY_NO_INIT

- (id)initWithCrashStackEntryMapper:(SentryCrashStackEntryMapper *)crashStackEntryMapper;

/**
 * Builds the stacktrace for the current thread using async safe functions, removing frames from the
 * SentrySDK until frames from a different package are found. When including Sentry via the Swift
 * Package Manager the package is the same as the application that includes Sentry. In this case the
 * full stacktrace is returned without skipping frames.
 */
- (SentryStacktrace *)buildStacktraceForCurrentThread;

/**
 * Retrieve the stacktrace for the current thread using native API, removing frames from the
 * SentrySDK until frames from a different package are found. When including Sentry via the Swift
 * Package Manager the package is the same as the application that includes Sentry. In this case the
 * full stacktrace is returned without skipping frames.
 * This function is not async safe but is faster than the 'buildStacktraceForCurrentThread'
 * alternative.
 */
- (nullable SentryStacktrace *)buildStacktraceForCurrentThreadAsyncUnsafe;

/** Maps youngest-to-oldest instruction addresses after all target threads have resumed. */
- (SentryStacktrace *)buildStackTraceFromAddresses:(NSArray<NSNumber *> *)addresses;
/**
 * Builds a stacktrace with the provided frames
 */
+ (SentryStacktrace *)buildStacktraceFromFrames:(NSArray<SentryFrame *> *)frames;
@end

NS_ASSUME_NONNULL_END
