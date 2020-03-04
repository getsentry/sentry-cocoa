#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDefines.h>
#else
#import "SentryDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentrySerialization : NSObject

+ (NSData *_Nullable)dataWithJSONObject:(NSDictionary *)dictionary
                                options:(NSJSONWritingOptions)opt
                                  error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
