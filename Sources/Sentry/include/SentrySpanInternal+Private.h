#import "SentrySpanInternal.h"

#import "SentryProfilingConditionals.h"
#import "SentrySwift.h"

static NSString *_Nonnull const kSentrySpanStatusSerializationKey = @"status";

// Visible to .m files only. The public header cannot import the generated Swift header.
@interface SentrySpanInternal () <SentrySpan>

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (copy, nonatomic) NSString *_Nullable profileSessionID;
#endif //  SENTRY_TARGET_PROFILING_SUPPORTED

@end
