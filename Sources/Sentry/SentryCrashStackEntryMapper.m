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

- (SentryFrame *)sentryCrashStackEntryToSentryFrame:(SentryCrashStackEntry)stackEntry
{
    SentryFrame *frame = [[SentryFrame alloc] init];

    frame.instructionAddress = sentry_formatHexAddressUInt64(stackEntry.address);

    // Get image from the cache.
    SentryBinaryImageInfo *info = [SentryDependencyContainer.sharedInstance.binaryImageCache
        imageByAddress:(uint64_t)stackEntry.address];

    frame.imageAddress = sentry_formatHexAddressUInt64(info.address);
    frame.package = info.name;
    frame.inApp = @([self.inAppLogic isInApp:info.name]);

    return frame;
}

- (SentryFrame *)mapStackEntryWithCursor:(SentryCrashStackCursor)stackCursor
{
    return [self sentryCrashStackEntryToSentryFrame:stackCursor.stackEntry];
}

@end

NS_ASSUME_NONNULL_END
