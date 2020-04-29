#import <Foundation/Foundation.h>
#import "SentryRateLimitCategoryMapper.h"
#import "SentryRateLimitCategory.h"
#import "SentryEnvelopeItemType.h"

@interface SentryRateLimitCategoryMapper ()

@end

@implementation SentryRateLimitCategoryMapper

+ (NSString *_Nonnull)mapEventTypeToCategory:(NSString *)eventType {
    // Currently we classify every event type as error.
    // This is going to change in the future.
    return SentryRateLimitCategoryError;
}

@end
