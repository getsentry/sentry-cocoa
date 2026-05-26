#import <Foundation/Foundation.h>
#import <SentryObjC/SentryObjCAttachmentType.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * You can use an attachment to store additional files alongside an event.
 */
@interface SentryObjCAttachment : NSObject

/// The data of the attachment.
@property (nonatomic, readonly, strong, nullable) NSData *data;

/// The path of the attachment.
@property (nonatomic, readonly, copy, nullable) NSString *path;

/// The filename of the attachment to display in Sentry.
@property (nonatomic, readonly, copy) NSString *filename;

/// The content type of the attachment.
@property (nonatomic, readonly, copy, nullable) NSString *contentType;

/// The type of the attachment.
@property (nonatomic, readonly) SentryObjCAttachmentType attachmentType;

/**
 * Initializes an attachment with data. Sets the content type to @c "application/octet-stream".
 * @param data The data for the attachment.
 * @param filename The name of the attachment to display in Sentry.
 */
- (instancetype)initWithData:(NSData *)data filename:(NSString *)filename;

/**
 * Initializes an attachment with data.
 * @param data The data for the attachment.
 * @param filename The name of the attachment to display in Sentry.
 * @param contentType The content type of the attachment. Default is @c "application/octet-stream".
 */
- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType;

/**
 * Initializes an attachment with a path. Uses the last path component of the path as a filename
 * and sets the content type to @c "application/octet-stream".
 * @discussion The file located at the pathname is read lazily when the SDK captures an event or
 * transaction not when the attachment is initialized.
 * @param path The path of the file whose contents you want to upload to Sentry.
 */
- (instancetype)initWithPath:(NSString *)path;

/**
 * Initializes an attachment with a path. Sets the content type to @c "application/octet-stream".
 * @discussion The specified file is read lazily when the SDK captures an event or
 * transaction not when the attachment is initialized.
 * @param path The path of the file whose contents you want to upload to Sentry.
 * @param filename The name of the attachment to display in Sentry.
 */
- (instancetype)initWithPath:(NSString *)path filename:(NSString *)filename;

/**
 * Initializes an attachment with a path.
 * @discussion The specified file is read lazily when the SDK captures an event or
 * transaction not when the attachment is initialized.
 * @param path The path of the file whose contents you want to upload to Sentry.
 * @param filename The name of the attachment to display in Sentry.
 * @param contentType The content type of the attachment. Default is @c "application/octet-stream".
 */
- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType;

/**
 * Initializes an attachment with data.
 * @param data The data for the attachment.
 * @param filename The name of the attachment to display in Sentry.
 * @param contentType The content type of the attachment. Default is @c "application/octet-stream".
 * @param attachmentType The type of the attachment. Default is @c "EventAttachment".
 */
- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryObjCAttachmentType)attachmentType;

/**
 * Initializes an attachment with a path.
 * @param path The path of the file whose contents you want to upload to Sentry.
 * @param filename The name of the attachment to display in Sentry.
 * @param contentType The content type of the attachment. Default is @c "application/octet-stream".
 * @param attachmentType The type of the attachment. Default is @c "EventAttachment".
 */
- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryObjCAttachmentType)attachmentType;

@end

NS_ASSUME_NONNULL_END
