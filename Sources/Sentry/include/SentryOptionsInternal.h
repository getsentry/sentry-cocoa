#import "SentryOptionsObjC.h"
#import <Foundation/Foundation.h>

@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

@interface SentryOptionsInternal : NSObject

+ (nullable SentryOptions *)initWithDict:(NSDictionary<NSString *, id> *)options
                        didFailWithError:(NSError *_Nullable *_Nullable)error;

+ (nullable SentryOptionsObjC *)optionsFromDict:(NSDictionary<NSString *, id> *)options
                                          error:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(options(fromDict:));

@end

NS_ASSUME_NONNULL_END
