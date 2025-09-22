#import "SentrySerialization.h"
#import "SentryDateUtils.h"
#import "SentryEnvelopeAttachmentHeader.h"
#import "SentryError.h"
#import "SentryInternalDefines.h"
#import "SentryLevelMapper.h"
#import "SentryLogC.h"
#import "SentryModels+Serializable.h"
#import "SentrySwift.h"
#import "SentryTraceContext.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySerialization

+ (NSData *_Nullable)dataWithJSONObject:(id)jsonObject
{
    if (![NSJSONSerialization isValidJSONObject:jsonObject]) {
        SENTRY_LOG_ERROR(@"Dictionary is not a valid JSON object.");
        return nil;
    }

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:&error];
    if (error) {
        SENTRY_LOG_ERROR(@"Internal error while serializing JSON: %@", error);
    }

    return data;
}

+ (NSData *_Nullable)dataWithEnvelope:(SentryEnvelope *)envelope
{
    NSMutableData *envelopeData = [[NSMutableData alloc] init];
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    if (nil != envelope.header.eventId) {
        [serializedData setValue:[envelope.header.eventId sentryIdString] forKey:@"event_id"];
    }

    SentrySdkInfo *sdkInfo = envelope.header.sdkInfo;
    if (nil != sdkInfo) {
        [serializedData setValue:[sdkInfo serialize] forKey:@"sdk"];
    }

    SentryTraceContext *traceContext = envelope.header.traceContext;
    if (traceContext != nil) {
        [serializedData setValue:[traceContext serialize] forKey:@"trace"];
    }

    NSDate *sentAt = envelope.header.sentAt;
    if (sentAt != nil) {
        [serializedData setValue:sentry_toIso8601String(sentAt) forKey:@"sent_at"];
    }
    NSData *header = [SentrySerialization dataWithJSONObject:serializedData];
    if (nil == header) {
        SENTRY_LOG_ERROR(@"Envelope header cannot be converted to JSON.");
        return nil;
    }
    [envelopeData appendData:header];

    NSData *_Nonnull const newLineData = [NSData dataWithBytes:"\n" length:1];
    for (int i = 0; i < envelope.items.count; ++i) {
        [envelopeData appendData:newLineData];
        NSDictionary *serializedItemHeaderData = [envelope.items[i].header serialize];

        NSData *itemHeader = [SentrySerialization dataWithJSONObject:serializedItemHeaderData];
        if (nil == itemHeader) {
            SENTRY_LOG_ERROR(@"Envelope item header cannot be converted to JSON.");
            return nil;
        }
        [envelopeData appendData:itemHeader];
        [envelopeData appendData:newLineData];
        [envelopeData appendData:envelope.items[i].data];
    }

    return envelopeData;
}

+ (NSData *_Nullable)dataWithSession:(SentrySession *)session
{
    return [self dataWithJSONObject:[session serialize]];
}

+ (NSDictionary *_Nullable)deserializeDictionaryFromJsonData:(NSData *)data
{
    NSError *error = nil;
    NSDictionary *_Nullable eventDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                              options:0
                                                                                error:&error];
    if (nil != error) {
        SENTRY_LOG_ERROR(@"Failed to deserialize json item dictionary: %@", error);
    }

    return eventDictionary;
}

+ (SentryLevel)levelFromData:(NSData *)eventEnvelopeItemData
{
    NSError *error = nil;
    NSDictionary *eventDictionary = [NSJSONSerialization JSONObjectWithData:eventEnvelopeItemData
                                                                    options:0
                                                                      error:&error];
    if (nil != error) {
        SENTRY_LOG_ERROR(@"Failed to retrieve event level from envelope item data: %@", error);
        return kSentryLevelError;
    }

    return sentryLevelForString(eventDictionary[@"level"]);
}

+ (NSArray *_Nullable)deserializeArrayFromJsonData:(NSData *)data
{
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (nil != error) {
        SENTRY_LOG_ERROR(@"Failed to deserialize json item array: %@", error);
        return nil;
    }
    if (![json isKindOfClass:[NSArray class]]) {
        SENTRY_LOG_ERROR(
            @"Deserialized json is not an NSArray, found %@", NSStringFromClass([json class]));
        return nil;
    }
    return (NSArray *)json;
}

@end

NS_ASSUME_NONNULL_END
