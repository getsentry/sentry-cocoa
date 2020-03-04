#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentrySerialization.h>
#import <Sentry/SentryDefines.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryError.h>
#else
#import "SentrySerialization.h"
#import "SentryDefines.h"
#import "SentryLog.h"
#import "SentryError.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySerialization

+ (NSData *_Nullable)dataWithJSONObject:(NSDictionary *)dictionary
                                options:(NSJSONWritingOptions)opt
                                  error:(NSError *_Nullable *_Nullable)error {

    NSData *data = nil;
    if ([NSJSONSerialization isValidJSONObject:dictionary] != NO) {
        data = [NSJSONSerialization dataWithJSONObject:dictionary options:opt error:error];
    } else {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Invalid JSON."] andLevel:kSentryLogLevelError];
        if (error) {
            *error = NSErrorFromSentryError(kSentryErrorJsonConversionError, @"Event cannot be converted to JSON");
        }
    }

    return data;
}

+ (NSData *_Nullable)dataWithEnvelope:(SentryEnvelope *)envelope
                              options:(NSJSONWritingOptions)opt
                                error:(NSError *_Nullable *_Nullable)error {

    NSMutableData *envelopeData = [[NSMutableData alloc] init];
    NSData *header = [SentrySerialization dataWithJSONObject:envelope.header options:opt error:error];
    if (nil == header) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Envelope header cannot be converted to JSON."] andLevel:kSentryLogLevelError];
        if (error) {
            *error = NSErrorFromSentryError(kSentryErrorJsonConversionError, @"Envelope header cannot be converted to JSON");
        }
        return nil;
    }
    [envelopeData appendData:header];

    for (int i = 0; i < envelope.items.count; ++i) {
        [envelopeData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
        NSData *itemHeader = [SentrySerialization dataWithJSONObject:envelope.items[i].header options:opt error:error];
        if (nil == itemHeader) {
            [SentryLog logWithMessage:[NSString stringWithFormat:@"Envelope item header cannot be converted to JSON."] andLevel:kSentryLogLevelError];
            if (error) {
                *error = NSErrorFromSentryError(kSentryErrorJsonConversionError, @"Envelope item header cannot be converted to JSON");
            }
            return nil;
        }
        [envelopeData appendData:itemHeader];
        [envelopeData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [envelopeData appendData:envelope.items[i].data];
    }

    return envelopeData;
}


@end

NS_ASSUME_NONNULL_END
