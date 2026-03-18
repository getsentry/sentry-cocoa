#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Attachment type for downstream SDKs.
 */
typedef NS_ENUM(NSInteger, SentryAttachmentType) {
    /** General event attachment */
    kSentryAttachmentTypeEventAttachment,
    /** View hierarchy attachment */
    kSentryAttachmentTypeViewHierarchy
};

/**
 * Additional file to store alongside an event.
 *
 * Attachments can be used to send additional files (logs, screenshots, etc.)
 * with Sentry events. They can be created from in-memory data or from files
 * on disk.
 *
 * @see SentryScope
 */
@interface SentryAttachment : NSObject

SENTRY_NO_INIT

/**
 * Creates an attachment from in-memory data.
 *
 * @param data The file data.
 * @param filename The filename to use for this attachment.
 * @return A new attachment instance.
 */
- (instancetype)initWithData:(NSData *)data filename:(NSString *)filename;

/**
 * Creates an attachment from in-memory data with a content type.
 *
 * @param data The file data.
 * @param filename The filename to use for this attachment.
 * @param contentType MIME type of the attachment (e.g., "text/plain", "image/png").
 * @return A new attachment instance.
 */
- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType;

/**
 * Creates an attachment from a file path.
 *
 * The filename is derived from the path.
 *
 * @param path Path to the file to attach.
 * @return A new attachment instance.
 */
- (instancetype)initWithPath:(NSString *)path;

/**
 * Creates an attachment from a file path with a custom filename.
 *
 * @param path Path to the file to attach.
 * @param filename The filename to use for this attachment.
 * @return A new attachment instance.
 */
- (instancetype)initWithPath:(NSString *)path filename:(NSString *)filename;

/**
 * Creates an attachment from a file path with filename and content type.
 *
 * @param path Path to the file to attach.
 * @param filename The filename to use for this attachment.
 * @param contentType MIME type of the attachment.
 * @return A new attachment instance.
 */
- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType;

/**
 * Creates an attachment from in-memory data with full options.
 *
 * @param data The file data.
 * @param filename The filename to use for this attachment.
 * @param contentType MIME type of the attachment.
 * @param attachmentType The type of attachment.
 * @return A new attachment instance.
 */
- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType;

/**
 * Creates an attachment from a file path with full options.
 *
 * @param path Path to the file to attach.
 * @param filename The filename to use for this attachment.
 * @param contentType MIME type of the attachment.
 * @param attachmentType The type of attachment.
 * @return A new attachment instance.
 */
- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType;

/**
 * The attachment data, if created from data.
 *
 * @c nil for path-based attachments.
 */
@property (readonly, nonatomic, strong, nullable) NSData *data;

/**
 * The file path, if created from a path.
 *
 * @c nil for data-based attachments.
 */
@property (readonly, nonatomic, copy, nullable) NSString *path;

/**
 * The filename for this attachment.
 */
@property (readonly, nonatomic, copy) NSString *filename;

/**
 * MIME type of the attachment.
 */
@property (readonly, nonatomic, copy, nullable) NSString *contentType;

/**
 * The type of this attachment.
 */
@property (readonly, nonatomic) SentryAttachmentType attachmentType;

@end

NS_ASSUME_NONNULL_END
