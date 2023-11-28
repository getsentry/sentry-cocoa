#import "SentryDebugMeta.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryDebugMeta

+ (void)load
{
    printf("%llu %s\n", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (instancetype)init
{
    return [super init];
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    serializedData[@"uuid"] = self.uuid;
    serializedData[@"debug_id"] = self.debugID;
    serializedData[@"type"] = self.type;
    serializedData[@"image_addr"] = self.imageAddress;
    serializedData[@"image_size"] = self.imageSize;
    serializedData[@"name"] = [self.name lastPathComponent];
    serializedData[@"code_file"] = self.codeFile;
    serializedData[@"image_vmaddr"] = self.imageVmAddress;

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
