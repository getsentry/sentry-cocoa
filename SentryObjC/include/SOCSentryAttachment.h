#import <Foundation/Foundation.h>
#import "SOCSentryAttachmentType.h"

NS_ASSUME_NONNULL_BEGIN

/// File or in-memory data sent alongside an event.
@interface SOCSentryAttachment : NSObject

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
              attachmentType:(SOCSentryAttachmentType)attachmentType;
- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SOCSentryAttachmentType)attachmentType;

@property (nonatomic, readonly, copy, nullable) NSData *data;
@property (nonatomic, readonly, copy, nullable) NSString *path;
@property (nonatomic, readonly, copy) NSString *filename;
@property (nonatomic, readonly, copy, nullable) NSString *contentType;
@property (nonatomic, readonly) SOCSentryAttachmentType attachmentType;

@end

NS_ASSUME_NONNULL_END
