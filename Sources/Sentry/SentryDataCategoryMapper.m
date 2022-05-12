#import "SentryDataCategoryMapper.h"
#import "SentryDataCategory.h"
#import "SentryEnvelopeItemType.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDataCategoryMapper ()

@end

@implementation SentryDataCategoryMapper

+ (SentryDataCategory)mapEventTypeToCategory:(NSString *)eventType
{
    // Currently we classify every event type as error.
    // This is going to change in the future.
    return kSentryDataCategoryError;
}

+ (SentryDataCategory)mapEnvelopeItemTypeToCategory:(NSString *)itemType
{
    SentryDataCategory category = kSentryDataCategoryDefault;
    if ([itemType isEqualToString:SentryEnvelopeItemTypeEvent]) {
        category = kSentryDataCategoryError;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeSession]) {
        category = kSentryDataCategorySession;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeTransaction]) {
        category = kSentryDataCategoryTransaction;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeAttachment]) {
        category = kSentryDataCategoryAttachment;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeProfile]) {
        category = kSentryDataCategoryProfile;
    }
    return category;
}

+ (SentryDataCategory)mapIntegerToCategory:(NSUInteger)value
{
    SentryDataCategory category = kSentryDataCategoryUnknown;

    if (value == kSentryDataCategoryAll) {
        category = kSentryDataCategoryAll;
    }
    if (value == kSentryDataCategoryDefault) {
        category = kSentryDataCategoryDefault;
    }
    if (value == kSentryDataCategoryError) {
        category = kSentryDataCategoryError;
    }
    if (value == kSentryDataCategorySession) {
        category = kSentryDataCategorySession;
    }
    if (value == kSentryDataCategoryTransaction) {
        category = kSentryDataCategoryTransaction;
    }
    if (value == kSentryDataCategoryAttachment) {
        category = kSentryDataCategoryAttachment;
    }
    if (value == kSentryDataCategoryUserFeedback) {
        category = kSentryDataCategoryUserFeedback;
    }
    if (value == kSentryDataCategoryProfile) {
        category = kSentryDataCategoryProfile;
    }
    if (value == kSentryDataCategoryUnknown) {
        category = kSentryDataCategoryUnknown;
    }

    return category;
}

+ (SentryDataCategory)mapStringToCategory:(NSString *)value
{
    SentryDataCategory category = kSentryDataCategoryUnknown;

    for (int i = 0; i <= kSentryDataCategoryUnknown; i++) {
        if ([value isEqualToString:SentryDataCategoryNames[i]]) {
            return [SentryDataCategoryMapper mapIntegerToCategory:i];
        }
    }

    return category;
}

@end

NS_ASSUME_NONNULL_END
