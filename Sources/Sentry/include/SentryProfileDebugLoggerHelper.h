#import <Foundation/Foundation.h>

#if defined(DEBUG)

@class SentrySample;

NS_ASSUME_NONNULL_BEGIN

@interface SentryProfileLoggerHelper : NSObject

+ (uint64_t)getAbsoluteTimeStampFromSample:(SentrySample *)sample;

@end

NS_ASSUME_NONNULL_END

#endif defined(DEBUG)
