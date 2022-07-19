#import "SentryOptions.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryOptions (Private)

@property (nullable, nonatomic, copy, readonly) NSNumber *defaultTracesSampleRate;

@property (nullable, nonatomic, copy, readonly) NSNumber *defaultProfilesSampleRate;

- (BOOL)isValidSampleRate:(NSNumber *)sampleRate;

- (BOOL)isValidTracesSampleRate:(NSNumber *)tracesSampleRate;

- (BOOL)isValidProfilesSampleRate:(NSNumber *)profilesSampleRate;

@property (nonatomic, strong, readonly) NSSet<NSString *> *enabledIntegrations;

- (void)removeEnabledIntegration:(NSString *)integration;

@end

NS_ASSUME_NONNULL_END
