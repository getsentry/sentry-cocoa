#import "SentryCrashThread.h"
#import "SentryDefines.h"
#import "SentryOptionsObjC.h"
#import <Foundation/Foundation.h>

@class SentryStacktrace;
@class SentryStacktraceBuilder;
@class SentryThread;

@protocol SentryCrashMachineContextWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface SentryDefaultThreadInspector : NSObject
SENTRY_NO_INIT

- (id)initWithStacktraceBuilder:(SentryStacktraceBuilder *)stacktraceBuilder
       andMachineContextWrapper:(id<SentryCrashMachineContextWrapper>)machineContextWrapper
                    symbolicate:(BOOL)symbolicate;

- (instancetype)initWithOptions:(SentryOptionsObjC *_Nullable)options;

- (nullable SentryStacktrace *)stacktraceForCurrentThreadAsyncUnsafe;

/**
 * Gets current threads with the stacktrace only for the current thread. Frames from the SentrySDK
 * are not included. For more details checkout SentryStacktraceBuilder.
 * The first thread in the result is always the main thread.
 */
- (NSArray<SentryThread *> *)getCurrentThreads;

/**
 * Gets current threads with stacktrace,
 * this will pause every thread in order to be possible to retrieve this information.
 * Frames from the SentrySDK are not included. For more details checkout SentryStacktraceBuilder.
 * The first thread in the result is always the main thread.
 */
- (NSArray<SentryThread *> *)getCurrentThreadsWithStackTrace;

- (nullable NSString *)getThreadName:(SentryCrashThread)thread;

@end

NS_ASSUME_NONNULL_END
