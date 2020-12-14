#import "SentryAttachment.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const DefaultContentType = @"application/octet-stream";

@implementation SentryAttachment

- (instancetype)initWithData:(NSData *)data filename:(NSString *)filename
{
    return [self initWithData:data filename:filename contentType:DefaultContentType];
}

- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(NSString *)contentType
{

    if (self = [super init]) {
        _data = data;
        _filename = filename;
        _contentType = contentType;
    }
    return self;
}

- (instancetype)initPath:(NSString *)path
{
    return [self initPath:path filename:[path lastPathComponent]];
}

- (instancetype)initPath:(NSString *)path filename:(NSString *)filename
{
    return [self initPath:path filename:filename contentType:DefaultContentType];
}

- (instancetype)initPath:(NSString *)path
                filename:(NSString *)filename
             contentType:(NSString *)contentType
{
    if (self = [super init]) {
        _path = path;
        _filename = filename;
        _contentType = contentType;
    }
    return self;
}

- (BOOL)isEqual:(id _Nullable)other
{
    if (other == self)
        return YES;
    if (!other || ![[other class] isEqual:[self class]])
        return NO;

    return [self isEqualToAttachment:other];
}

- (BOOL)isEqualToAttachment:(SentryAttachment *)attachment
{
    if (self == attachment)
        return YES;
    if (attachment == nil)
        return NO;
    if (self.data != attachment.data && ![self.data isEqualToData:attachment.data])
        return NO;
    if (self.path != attachment.path && ![self.path isEqualToString:attachment.path])
        return NO;
    if (self.filename != attachment.filename
        && ![self.filename isEqualToString:attachment.filename])
        return NO;
    return !(self.contentType != attachment.contentType
        && ![self.contentType isEqualToString:attachment.contentType]);
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 23 + [self.data hash];
    hash = hash * 23 + [self.path hash];
    hash = hash * 23 + [self.filename hash];
    hash = hash * 23 + [self.contentType hash];

    return hash;
}

@end

NS_ASSUME_NONNULL_END
