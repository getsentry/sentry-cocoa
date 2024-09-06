#import "SentryDefines.h"

@class SentrySession, SentryEnvelope, SentryAppState, SentryReplayRecording;

NS_ASSUME_NONNULL_BEGIN

typedef void (^SentryDataWriter)(NSData *data);

@interface SentrySerialization : NSObject

+ (NSData *_Nullable)dataWithJSONObject:(id)jsonObject;

+ (NSData *_Nullable)dataWithSession:(SentrySession *)session;

+ (SentrySession *_Nullable)sessionWithData:(NSData *)sessionData;

+ (BOOL)writeEnvelopeData:(SentryEnvelope *)envelope writeData:(SentryDataWriter)writeData;

/**
 * For large envelopes, consider using @c writeEnvelopeData, which lets you write the envelope in
 * chunks to your desired location, to minimize the memory footprint.
 */
+ (NSData *_Nullable)dataWithEnvelope:(SentryEnvelope *)envelope;

+ (NSData *)dataWithReplayRecording:(SentryReplayRecording *)replayRecording;

+ (SentryEnvelope *_Nullable)envelopeWithData:(NSData *)data;

+ (SentryAppState *_Nullable)appStateWithData:(NSData *)sessionData;

/**
 * Retrieves the json object from an event envelope item data.
 */
+ (NSDictionary *)deserializeDictionaryFromJsonData:(NSData *)data;

/**
 * Extract the level from data of an envelopte item containing an event. Default is the 'error'
 * level, see https://develop.sentry.dev/sdk/event-payloads/#optional-attributes
 */
+ (SentryLevel)levelFromData:(NSData *)eventEnvelopeItemData;

@end

NS_ASSUME_NONNULL_END
