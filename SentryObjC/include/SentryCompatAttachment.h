#import <Foundation/Foundation.h>
#import "SentryCompatAttachmentType.h"

NS_ASSUME_NONNULL_BEGIN

/// File or in-memory data sent alongside an event.
@interface SentryCompatAttachment : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

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
              attachmentType:(SentryCompatAttachmentType)attachmentType;
- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryCompatAttachmentType)attachmentType;

@property (nonatomic, readonly, copy, nullable) NSData *data;
@property (nonatomic, readonly, copy, nullable) NSString *path;
@property (nonatomic, readonly, copy) NSString *filename;
@property (nonatomic, readonly, copy, nullable) NSString *contentType;
@property (nonatomic, readonly) SentryCompatAttachmentType attachmentType;

@end

NS_ASSUME_NONNULL_END
