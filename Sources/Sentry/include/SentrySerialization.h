#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDefines.h>
#import <Sentry/SentryEnvelope.h>
#else
#import "SentryDefines.h"
#import "SentryEnvelope.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentrySerialization : NSObject

+ (NSData *_Nullable)dataWithJSONObject:(NSDictionary *)dictionary
                                options:(NSJSONWritingOptions)opt
                                  error:(NSError *_Nullable *_Nullable)error;

+ (NSData *_Nullable)dataWithEnvelope:(SentryEnvelope *)envelope
                                options:(NSJSONWritingOptions)opt
                                  error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
