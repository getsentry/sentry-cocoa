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

#if !SDK_V10
- (SentryFrame *)sentryCrashStackEntryToSentryFrame:(SentryCrashStackEntry)stackEntry
{
    return [self mapAddress:stackEntry.address];
}
#endif

- (SentryFrame *)mapAddress:(uintptr_t)address
{
    SentryFrame *frame = [[SentryFrame alloc] init];

    frame.instructionAddress = sentry_formatHexAddressUInt64(address);

    // Get image from the cache.
    SentryBinaryImageInfo *info = [SentryDependencyContainer.sharedInstance.binaryImageCache
        imageByAddress:(uint64_t)address];

    frame.imageAddress = sentry_formatHexAddressUInt64(info.address);
    frame.package = info.name;
    frame.inApp = @([self.inAppLogic isInApp:info.name]);

    return frame;
}

#if !SDK_V10
- (SentryFrame *)mapStackEntryWithCursor:(SentryCrashStackCursor)stackCursor
{
    return [self sentryCrashStackEntryToSentryFrame:stackCursor.stackEntry];
}
#endif

@end

NS_ASSUME_NONNULL_END
