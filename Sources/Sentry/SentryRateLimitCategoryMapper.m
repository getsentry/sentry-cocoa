#import <Foundation/Foundation.h>
#import "SentryRateLimitCategoryMapper.h"
#import "SentryRateLimitCategory.h"
#import "SentryEnvelopeItemType.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryRateLimitCategoryMapper ()

@end

@implementation SentryRateLimitCategoryMapper

+ (SentryRateLimitCategory)mapEventTypeToCategory:(NSString *)eventType {
    // Currently we classify every event type as error.
    // This is going to change in the future.
    return kSentryRateLimitCategoryError;
}

+ (SentryRateLimitCategory)mapEnvelopeItemTypeToCategory:(NSString *)itemType {
    SentryRateLimitCategory category = kSentryRateLimitCategoryDefault;
    if ([itemType isEqualToString:SentryEnvelopeItemTypeEvent]) {
        category = kSentryRateLimitCategoryError;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeSession]) {
        category = kSentryRateLimitCategorySession;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeTransaction]) {
        category = kSentryRateLimitCategoryTransaction;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeAttachment]) {
        category = kSentryRateLimitCategoryAttachment;
    }
    return category;
}

@end

NS_ASSUME_NONNULL_END
