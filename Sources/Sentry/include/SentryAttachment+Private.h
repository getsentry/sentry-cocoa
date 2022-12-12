#import "SentryAttachment.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Attachment Type
 */
typedef NS_ENUM(NSInteger, SentryAttachmentType) {
    kSentryAttachmentTypeEventAttachment,
    kSentryAttachmentTypeViewHierarchy
};

@interface
SentryAttachment ()
SENTRY_NO_INIT

/**
 * Initializes an attachment with data.
 *
 * @param data The data for the attachment.
 * @param filename The name of the attachment to display in Sentry.
 * @param contentType The content type of the attachment. Default is "application/octet-stream".
 * @param attachmentType The type of the attachment. Default is "EventAttachment".
 */
- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType;

/**
 * Initializes an attachment with data.
 *
 * @param path The path of the file whose contents you want to upload to Sentry.
 * @param filename The name of the attachment to display in Sentry.
 * @param contentType The content type of the attachment. Default is "application/octet-stream".
 * @param attachmentType The type of the attachment. Default is "EventAttachment".
 */
- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType;

/**
 * The type of the attachment.
 */
@property (readonly, nonatomic) SentryAttachmentType attachmentType;

@end

FOUNDATION_EXPORT NSString *const kSentryAttachmentTypeNameEventAttachment;
FOUNDATION_EXPORT NSString *const kSentryAttachmentTypeNameViewHierarchy;

NSString *nameForSentryAttachmentType(SentryAttachmentType attachmentType);

NS_ASSUME_NONNULL_END
