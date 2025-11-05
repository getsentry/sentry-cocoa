#import <Foundation/Foundation.h>

@class SentryOptionsInternal;
@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

@interface SentryOptionsConverter : NSObject

+ (SentryOptions *)fromInternal:(SentryOptionsInternal *)internalOptions;

+ (SentryOptionsInternal *)toInternal:(SentryOptions *)internalOptions;

@end

NS_ASSUME_NONNULL_END
