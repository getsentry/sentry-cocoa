#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryCompiler.h"

@class SentryHub;
@class SentryScreenFrames;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN_C_BEGIN

/*
 * Parses a symbol that is returned from `backtrace_symbols()`, which encodes information
 * like the frame index, image name, function name, and offset in a single string. e.g.
 * For the input:
 * 2   UIKitCore                           0x00000001850d97ac -[UIFieldEditor
 * _fullContentInsetsFromFonts] + 160 This function would return: -[UIFieldEditor
 * _fullContentInsetsFromFonts]
 *
 * If the format does not match the expected format, this returns the input string.
 */
NSString *parseBacktraceSymbolsFunctionName(const char *symbol);

SENTRY_EXTERN_C_END

@class SentryEnvelopeItem, SentryTransaction;

@interface SentryProfiler : NSObject

/** Clears all accumulated profiling data and starts profiling. */
- (void)start;

/** Stops profiling. */
- (void)stop;

/** Whether or not the sampling profiler is currently running. */
- (BOOL)isRunning;

/**
 * Builds an envelope item using the currently accumulated profile data.
 */
- (nullable SentryEnvelopeItem *)buildEnvelopeItemForTransaction:(SentryTransaction *)transaction
                                                             hub:(SentryHub *)hub
                                                       frameInfo:
                                                           (nullable SentryScreenFrames *)frameInfo;

@end

NS_ASSUME_NONNULL_END

#endif
