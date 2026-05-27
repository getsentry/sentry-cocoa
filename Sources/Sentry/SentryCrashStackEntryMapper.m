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
    // KSStackCursor.stackEntry is an anonymous struct; copy fields into named
    // SentryCrashStackEntry.
    SentryCrashStackEntry entry;
    entry.address = stackCursor.stackEntry.address;
    entry.imageName = stackCursor.stackEntry.imageName;
    entry.imageAddress = stackCursor.stackEntry.imageAddress;
    entry.symbolName = stackCursor.stackEntry.symbolName;
    entry.symbolAddress = stackCursor.stackEntry.symbolAddress;
    return [self sentryCrashStackEntryToSentryFrame:entry];
}

@end

NS_ASSUME_NONNULL_END
