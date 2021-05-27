#import "SentrySDK.h"

@class SentryId, SentryEnvelope;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDK (Private)

+ (void)captureCrashEvent:(SentryEvent *)event;

/**
 * SDK private field to store the state if onCrashedLastRun was called.
 */
@property (nonatomic, class) BOOL crashedLastRunCalled;

+ (SentryHub *)currentHub;

/**
 * Needed by hybrid SDKs as react-native to synchronously store an envelope to disk.
 */
+ (void)storeEnvelope:(SentryEnvelope *)envelope;

/**
 * Needed by hybrid SDKs as react-native to synchronously capture an envelope.
 */
+ (void)captureEnvelope:(SentryEnvelope *)envelope;

@end

NS_ASSUME_NONNULL_END
