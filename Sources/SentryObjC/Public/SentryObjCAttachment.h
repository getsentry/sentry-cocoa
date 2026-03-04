#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Attachment type for downstream SDKs.
 */
typedef NS_ENUM(NSInteger, SentryAttachmentType) {
    kSentryAttachmentTypeEventAttachment,
    kSentryAttachmentTypeViewHierarchy
};

/**
 * Additional file to store alongside an event.
 *
 * @see SentryScope
 */
@interface SentryAttachment : NSObject

SENTRY_NO_INIT

- (instancetype)initWithData:(NSData *)data filename:(NSString *)filename;
- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType;
- (instancetype)initWithPath:(NSString *)path;
- (instancetype)initWithPath:(NSString *)path filename:(NSString *)filename;
- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType;
- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType;
- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType;

@property (readonly, nonatomic, strong, nullable) NSData *data;
@property (readonly, nonatomic, copy, nullable) NSString *path;
@property (readonly, nonatomic, copy) NSString *filename;
@property (readonly, nonatomic, copy, nullable) NSString *contentType;
@property (readonly, nonatomic) SentryAttachmentType attachmentType;

@end

NS_ASSUME_NONNULL_END
