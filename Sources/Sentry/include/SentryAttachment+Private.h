#import "SentryAttachment.h"
#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentryAttachmentTypeNameEventAttachment;
FOUNDATION_EXPORT NSString *const kSentryAttachmentTypeNameViewHierarchy;

NSString *nameForSentryAttachmentType(SentryAttachmentType attachmentType);

SentryAttachmentType typeForSentryAttachmentName(NSString *_Nullable name);

NS_ASSUME_NONNULL_END
