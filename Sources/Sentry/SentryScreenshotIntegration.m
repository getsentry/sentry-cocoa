#import "SentryScreenshotIntegration.h"
#import "SentryAttachment.h"
#import "SentryClient+Private.h"
#import "SentryDependencyContainer.h"
#import "SentryEvent.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import "SentrySDK+Private.h"

#if SENTRY_HAS_UIKIT
@implementation SentryScreenshotIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    if ([self shouldBeDisabled:options]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    SentryClient *client = [SentrySDK.currentHub getClient];
    client.attachmentProcessor = self;
}

- (NSArray<SentryAttachment *> *)processAttachments:(NSArray<SentryAttachment *> *)attachments
                                           forEvent:(nonnull SentryEvent *)event
{

    if (event.exceptions == nil && event.error == nil)
        return attachments;

    NSArray *screenshot = [SentryDependencyContainer.sharedInstance.screenshot appScreenshots];

    NSMutableArray *result =
        [NSMutableArray arrayWithCapacity:attachments.count + screenshot.count];
    [result addObjectsFromArray:attachments];

    for (int i = 0; i < screenshot.count; i++) {
        NSString *name;
        if (i == 0)
            name = @"screenshot.png";
        else
            name = [NSString stringWithFormat:@"screenshot-%i.png", i + 1];

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
