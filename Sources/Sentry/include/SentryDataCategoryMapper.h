#import "SentryDataCategory.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameAll;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameDefault;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameError;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameSession;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameTransaction;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameAttachment;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameUserFeedback;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameProfile;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameUnknown;

SentryDataCategory categoryForNSUInteger(NSUInteger value);

SentryDataCategory categoryForString(NSString *value);

SentryDataCategory categoryForEnvelopItemType(NSString *itemType);

NSString *nameForCategory(SentryDataCategory category);

NS_ASSUME_NONNULL_END
