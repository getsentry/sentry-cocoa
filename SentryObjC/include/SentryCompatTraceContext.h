#import <Foundation/Foundation.h>

@class SentryCompatId;

NS_ASSUME_NONNULL_BEGIN

/// Trace-level context propagated in the baggage header.
@interface SentryCompatTraceContext : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, readonly, strong) SentryCompatId *traceId;
@property (nonatomic, readonly, copy) NSString *publicKey;
@property (nonatomic, readonly, copy, nullable) NSString *releaseName;
@property (nonatomic, readonly, copy, nullable) NSString *environment;
@property (nonatomic, readonly, copy, nullable) NSString *transaction;
@property (nonatomic, readonly, copy, nullable) NSString *sampleRate;
@property (nonatomic, readonly, copy, nullable) NSString *sampleRand;
@property (nonatomic, readonly, copy, nullable) NSString *sampled;
@property (nonatomic, readonly, copy, nullable) NSString *replayId;
@property (nonatomic, readonly, copy, nullable) NSString *orgId;

@end

NS_ASSUME_NONNULL_END
