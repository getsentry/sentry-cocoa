#import "SentryDebugMeta.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryDebugMeta

- (instancetype)init
{
    return [super init];
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:self.uuid forKey:@"uuid"];
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:self.imageAddress forKey:@"image_addr"];
    [serializedData setValue:self.imageSize forKey:@"image_size"];
    [serializedData setValue:[self.name lastPathComponent] forKey:@"name"];
    [serializedData setValue:self.imageVmAddress forKey:@"image_vmaddr"];

    return serializedData;
}

- (BOOL)isEqual:(id)object;
{
    if (self == object)
        return YES;
    if ([self class] != [object class])
        return NO;

    SentryDebugMeta *other = (SentryDebugMeta *)object;
    if (!(_uuid == other.uuid || [_uuid isEqualToString:other.uuid]))
        return NO;

    if (!(_type == other.type || [_type isEqualToString:other.type]))
        return NO;

    if (!(_name == other.name || [_name isEqualToString:other.name]))
        return NO;

    if (!(_imageSize == other.imageSize || [_imageSize isEqualToNumber:other.imageSize]))
        return NO;

    if (!(_imageAddress == other.imageAddress ||
            [_imageAddress isEqualToString:other.imageAddress]))
        return NO;

    if (!(_imageVmAddress == other.imageVmAddress ||
            [_imageVmAddress isEqualToString:other.imageVmAddress]))
        return NO;

    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 31 + [_uuid hash];
    hash = hash * 31 + [_type hash];
    hash = hash * 31 + [_name hash];
    hash = hash * 31 + [_imageSize unsignedIntValue];
    hash = hash * 31 + [_imageAddress hash];
    hash = hash * 31 + [_imageVmAddress hash];

    return hash;
}

@end

NS_ASSUME_NONNULL_END
