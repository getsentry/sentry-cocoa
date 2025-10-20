#import "SentryDebugImageProviderInternal.h"
#import "SentryCrashDynamicLinker.h"
#import "SentryCrashUUIDConversion.h"
#import "SentryDebugMeta.h"
#import "SentryDependencyContainer.h"
#import "SentryFormatter.h"
#import "SentryFrame.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import "SentryThread.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDebugImageProviderInternal ()

@property (nonatomic, strong) SentryBinaryImageCache *binaryImageCache;

@end

@implementation SentryDebugImageProviderInternal

- (instancetype)init
{
    self =
        [self initWithBinaryImageCache:SentryDependencyContainer.sharedInstance.binaryImageCache];

    return self;
}

/** Internal constructor for testing */
- (instancetype)initWithBinaryImageCache:(SentryBinaryImageCache *_Nullable)binaryImageCache
{
    if (self = [super init]) {
        if (binaryImageCache) {
            self.binaryImageCache = (SentryBinaryImageCache *)binaryImageCache;
        } else {
            self.binaryImageCache = SentryDependencyContainer.sharedInstance.binaryImageCache;
        }
    }
    return self;
}

- (void)extractDebugImageAddressFromFrames:(NSArray<SentryFrame *> *)frames
                                   intoSet:(NSMutableSet<NSString *> *)set
{
    for (SentryFrame *frame in frames) {
        if (frame.imageAddress) {
            [set addObject:SENTRY_UNWRAP_NULLABLE(NSString, frame.imageAddress)];
        }
    }
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesForImageAddressesFromCache:
    (NSSet<NSString *> *)imageAddresses
{
    NSMutableArray<SentryDebugMeta *> *result = [NSMutableArray array];

    for (NSString *imageAddress in imageAddresses) {
        const uint64_t imageAddressAsUInt64 = sentry_UInt64ForHexAddress(imageAddress);
        SentryBinaryImageInfo *info = [self.binaryImageCache imageByAddress:imageAddressAsUInt64];
        if (info == nil) {
            continue;
        }

        [result addObject:[self fillDebugMetaFromBinaryImageInfo:info]];
    }

    return result;
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCacheForFrames:(NSArray<SentryFrame *> *)frames
{
    NSMutableSet<NSString *> *imageAddresses = [[NSMutableSet alloc] init];
    [self extractDebugImageAddressFromFrames:frames intoSet:imageAddresses];

    return [self getDebugImagesForImageAddressesFromCache:imageAddresses];
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCacheForThreads:(NSArray<SentryThread *> *)threads
{
    NSMutableSet<NSString *> *imageAddresses = [[NSMutableSet alloc] init];

    for (SentryThread *thread in threads) {
        NSArray<SentryFrame *> *_Nullable frames = thread.stacktrace.frames;
        if (frames != nil) {
            [self extractDebugImageAddressFromFrames:SENTRY_UNWRAP_NULLABLE(NSArray, frames)
                                             intoSet:imageAddresses];
        }
    }

    return [self getDebugImagesForImageAddressesFromCache:imageAddresses];
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCache
{
    NSArray<SentryBinaryImageInfo *> *infos = [self.binaryImageCache getAllBinaryImages];
    NSMutableArray<SentryDebugMeta *> *result =
        [[NSMutableArray alloc] initWithCapacity:infos.count];
    for (SentryBinaryImageInfo *info in infos) {
        [result addObject:[self fillDebugMetaFromBinaryImageInfo:info]];
    }
    return result;
}

- (SentryDebugMeta *)fillDebugMetaFrom:(SentryCrashBinaryImage)image
{
    SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] init];
    debugMeta.debugID = [SentryBinaryImageCache convertUUID:image.uuid];
    debugMeta.type = SentryDebugImageType;

    if (image.vmAddress > 0) {
        debugMeta.imageVmAddress = sentry_formatHexAddressUInt64(image.vmAddress);
    }

    debugMeta.imageAddress = sentry_formatHexAddressUInt64(image.address);

    debugMeta.imageSize = @(image.size);

    if (nil != image.name) {
        debugMeta.codeFile = [[NSString alloc] initWithUTF8String:image.name];
    }

    return debugMeta;
}

- (SentryDebugMeta *)fillDebugMetaFromBinaryImageInfo:(SentryBinaryImageInfo *)info
{
    SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] init];
    debugMeta.debugID = info.uuid;
    debugMeta.type = SentryDebugImageType;

    if (info.vmAddress > 0) {
        debugMeta.imageVmAddress = sentry_formatHexAddressUInt64(info.vmAddress);
    }

    debugMeta.imageAddress = sentry_formatHexAddressUInt64(info.address);
    debugMeta.imageSize = @(info.size);
    debugMeta.codeFile = info.name;

    return debugMeta;
}

@end

NS_ASSUME_NONNULL_END
