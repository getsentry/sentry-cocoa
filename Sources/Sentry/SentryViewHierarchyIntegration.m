#import "SentryViewHierarchyIntegration.h"
#import "SentryAttachment.h"
#import "SentryClient+Private.h"
#import "SentryCrashC.h"
#import "SentryDependencyContainer.h"
#import "SentryEvent+Private.h"
#import "SentryEvent.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryViewHierarchy.h"

#if SENTRY_HAS_UIKIT

@implementation SentryViewHierarchyIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    SentryClient *client = [SentrySDK.currentHub getClient];
    [client addAttachmentProcessor:self];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionAttachViewHierarchy;
}

- (void)uninstall
{
    SentryClient *client = [SentrySDK.currentHub getClient];
    [client removeAttachmentProcessor:self];
}

- (NSArray<SentryAttachment *> *)processAttachments:(NSArray<SentryAttachment *> *)attachments
                                           forEvent:(nonnull SentryEvent *)event
{

    NSArray *decriptions = [SentryViewHierarchy fetchViewHierarchy];
    NSMutableArray *result =
        [NSMutableArray arrayWithCapacity:attachments.count + decriptions.count];
    [result addObjectsFromArray:attachments];

    [decriptions enumerateObjectsUsingBlock:^(NSString *decription, NSUInteger idx, BOOL *stop) {
        SentryAttachment *attachment = [[SentryAttachment alloc]
            initWithData:[decription dataUsingEncoding:NSUTF8StringEncoding]
                filename:[NSString stringWithFormat:@"view-hierarchy-%lu.txt", (unsigned long)idx]];
        [result addObject:attachment];
    }];

    return result;
}

@end
#endif
