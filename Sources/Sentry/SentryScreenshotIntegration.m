#import "SentryScreenshotIntegration.h"
#import "SentryAttachment.h"
#import "SentryClient+Private.h"
#import "SentryCrashC.h"
#import "SentryDependencyContainer.h"
#import "SentryEvent+Private.h"
#import "SentryEvent.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import "SentrySDK+Private.h"

#if SENTRY_HAS_UIKIT

void
saveScreenShot(const char *path)
{
    NSString *reportPath = [NSString stringWithUTF8String:path];
    NSError *error = nil;

    if (![NSFileManager.defaultManager fileExistsAtPath:reportPath]) {
        [NSFileManager.defaultManager createDirectoryAtPath:reportPath
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:&error];
        if (error != nil)
            return;
    } else {
        // We first delete any screenshot that could be from an old crash report
        NSArray *oldFiles = [NSFileManager.defaultManager contentsOfDirectoryAtPath:reportPath
                                                                              error:&error];

        if (!error) {
            [oldFiles enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                [NSFileManager.defaultManager removeItemAtPath:obj error:nil];
            }];
        }
    }

    [SentryDependencyContainer.sharedInstance.screenshot saveScreenShots:reportPath];
}

@implementation SentryScreenshotIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    if ([self shouldBeDisabled:options]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    SentryClient *client = [SentrySDK.currentHub getClient];
    client.attachmentProcessor = self;

    sentrycrash_setSaveScreenshots(&saveScreenShot);
}

- (void)uninstall
{
    sentrycrash_setSaveScreenshots(NULL);
}

- (NSArray<SentryAttachment *> *)processAttachments:(NSArray<SentryAttachment *> *)attachments
                                           forEvent:(nonnull SentryEvent *)event
{

    // We don't take screenshots if there is no exception/error.
    // We dont take screenshots if the event is a crash event.
    if ((event.exceptions == nil && event.error == nil) || event.isCrashEvent)
        return attachments;

    NSArray *screenshot = [SentryDependencyContainer.sharedInstance.screenshot appScreenshots];

    NSMutableArray *result =
        [NSMutableArray arrayWithCapacity:attachments.count + screenshot.count];
    [result addObjectsFromArray:attachments];

    for (int i = 0; i < screenshot.count; i++) {
        NSString *name
            = i == 0 ? @"screenshot.png" : [NSString stringWithFormat:@"screenshot-%i.png", i + 1];

        SentryAttachment *att = [[SentryAttachment alloc] initWithData:screenshot[i]
                                                              filename:name
                                                           contentType:@"image/png"];
        [result addObject:att];
    }

    return result;
}

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.attachScreenshot) {
        [SentryLog logWithMessage:@"Screenshot integration disabled." andLevel:kSentryLevelDebug];
        return YES;
    }

    return NO;
}

@end
#endif
