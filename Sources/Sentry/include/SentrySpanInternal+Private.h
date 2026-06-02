#import "SentrySpanInternal.h"

#import "SentryProfilingConditionals.h"

static NSString *_Nonnull const kSentrySpanStatusSerializationKey = @"status";

@interface SentrySpanInternal ()

- (void)addFeatureFlagWithName:(NSString *_Nonnull)name result:(BOOL)result;

- (NSDictionary<NSString *, id> *_Nonnull)serializeFeatureFlags;

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (copy, nonatomic) NSString *_Nullable profileSessionID;
#endif //  SENTRY_TARGET_PROFILING_SUPPORTED

@end
