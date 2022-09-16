#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryCompiler.h"

#    if SENTRY_HAS_UIKIT
@class SentryFramesTracker;
#    endif // SENTRY_HAS_UIKIT
@class SentryHub;
@class SentryProfilesSamplerDecision;
@class SentryScreenFrames;

typedef NS_ENUM(NSUInteger, SentryProfilerTruncationReason) {
    SentryProfilerTruncationReasonNormal,
    SentryProfilerTruncationReasonTimeout,
    SentryProfilerTruncationReasonAppMovedToBackground,
};

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

NSString *profilerTruncationReasonName(SentryProfilerTruncationReason reason);

SENTRY_EXTERN_C_END

@class SentryEnvelope;
@class SentryHub;
@class SentrySpanId;
@class SentryTransaction;

@interface SentryProfiler : NSObject

/**
 * Start the profiler, if it isn't already running, for the span with the provided ID. If it's
 * already running, it will track the new span as well.
 */
+ (void)startForSpanID:(SentrySpanId *)spanID;

/**
 * Stop the profiler, if appropriate, depending on the reason provided.
 */
+ (void)maybeStopProfilerForSpanID:(nullable SentrySpanId *)spanID
                            reason:(SentryProfilerTruncationReason)reason;

/**
 * If the provided transaction is the last needed for the profile, package its information and
 * capture in an envelope.
 */
+ (void)captureProfilingEnvelopeIfFinishedAfterTransaction:(SentryTransaction *)transaction
                                                       hub:(SentryHub *)hub;

+ (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END

#endif
