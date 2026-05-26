#import "SentryObjCAttachmentType.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCAttachment : NSObject

@property (nonatomic, readonly, strong, nullable) NSData *data;
@property (nonatomic, readonly, copy, nullable) NSString *path;
@property (nonatomic, readonly, copy) NSString *filename;
@property (nonatomic, readonly, copy, nullable) NSString *contentType;
@property (nonatomic, readonly) SentryObjCAttachmentType attachmentType;

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
              attachmentType:(SentryObjCAttachmentType)attachmentType;
- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryObjCAttachmentType)attachmentType;

@end

NS_ASSUME_NONNULL_END
