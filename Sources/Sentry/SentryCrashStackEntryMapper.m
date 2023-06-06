#import "SentryCrashStackEntryMapper.h"
#import "SentryFormatter.h"
#import "SentryFrame.h"
#import "SentryInAppLogic.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryCrashStackEntryMapper ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;
@property (nonatomic, strong) SentryBinaryImageCache *binaryImageCache;

@end

@implementation SentryCrashStackEntryMapper

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                  binaryImageCache:(SentryBinaryImageCache *)binaryImageCache
{
    if (self = [super init]) {
        self.inAppLogic = inAppLogic;
        self.binaryImageCache = binaryImageCache;
    }
    return self;
}

- (SentryFrame *)sentryCrashStackEntryToSentryFrame:(SentryCrashStackEntry)stackEntry
{
    SentryFrame *frame = [[SentryFrame alloc] init];

    frame.symbolAddress = sentry_formatHexAddressUInt64(stackEntry.symbolAddress);

    frame.instructionAddress = sentry_formatHexAddressUInt64(stackEntry.address);

    if (stackEntry.symbolName != NULL) {
        frame.function = [NSString stringWithCString:stackEntry.symbolName
                                            encoding:NSUTF8StringEncoding];
    }

    SentryBinaryImageInfo *info = [_binaryImageCache imageByAddress:stackEntry.address];

    if (info != nil && stackEntry.imageName == NULL) {
        frame.imageAddress = sentry_formatHexAddressUInt64(info.address);
        frame.package = info.name;
        frame.inApp = @([self.inAppLogic isInApp:info.name]);
    } else {
        frame.imageAddress = sentry_formatHexAddressUInt64(stackEntry.imageAddress);

        if (stackEntry.imageName != NULL) {
            NSString *imageName = [NSString stringWithCString:stackEntry.imageName
                                                     encoding:NSUTF8StringEncoding];
            frame.package = imageName;
            frame.inApp = @([self.inAppLogic isInApp:imageName]);
        }
    }

    return frame;
}

- (SentryFrame *)mapStackEntryWithCursor:(SentryCrashStackCursor)stackCursor
{
    return [self sentryCrashStackEntryToSentryFrame:stackCursor.stackEntry];
}

@end

NS_ASSUME_NONNULL_END
