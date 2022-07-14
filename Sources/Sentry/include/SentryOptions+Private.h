#import "SentryOptions.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryOptions (Private)

@property (nullable, nonatomic, copy, readonly) SentrySampleRate *defaultTracesSampleRate;

- (BOOL)isValidSampleRate:(SentrySampleRate *)sampleRate;

- (BOOL)isValidTracesSampleRate:(SentrySampleRate *)tracesSampleRate;

@property (nonatomic, strong, readonly) NSSet<NSString *> *enabledIntegrations;

- (void)removeEnabledIntegration:(NSString *)integration;

@end

NS_ASSUME_NONNULL_END
