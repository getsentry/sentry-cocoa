#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSDictionary *_Nullable sentry_sanitize_dictionary(
    NSDictionary *_Nullable dictionary);
SENTRY_EXTERN NSArray *sentry_sanitize_array(NSArray *array);

NS_ASSUME_NONNULL_END
