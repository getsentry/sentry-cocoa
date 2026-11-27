#import "SentryCrashStackEntryMapper.h"
#import "SentryFormatter.h"
#import "SentryFrame.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashStackEntryMapper ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;

@end

@implementation SentryCrashStackEntryMapper

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
{
    if (self = [super init]) {
        self.inAppLogic = inAppLogic;
    }
    return self;
}

- (SentryFrame *)mapAddress:(uintptr_t)address
{
    SentryFrame *frame = [[SentryFrame alloc] init];

    frame.instructionAddress = sentry_formatHexAddressUInt64(address);

    // Get image from the cache.
    SentryBinaryImageCache *cache = SentryDependencyContainer.sharedInstance.binaryImageCache;
    SentryBinaryImageInfo *info = [cache imageByAddress:(uint64_t)address];

    frame.imageAddress = sentry_formatHexAddressUInt64(info.address);
    frame.package = info.name;
    frame.inApp = @(
        (info != nil && [cache isMainExecutableImage:info]) || [self.inAppLogic isInApp:info.name]);

    return frame;
}

@end

NS_ASSUME_NONNULL_END
