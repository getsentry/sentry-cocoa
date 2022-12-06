#import "SentryAttachment+Equality.h"

@implementation
SentryAttachment (Equality)

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
    if (self.attachmentType != attachment.attachmentType)
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
    hash = hash * 23 + self.attachmentType;

    return hash;
}

@end
