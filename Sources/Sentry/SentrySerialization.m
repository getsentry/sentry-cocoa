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

@end

NS_ASSUME_NONNULL_END
