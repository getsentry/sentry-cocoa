#import "SentryAttachment.h"
#import "SentryClient+Private.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientInternal ()

- (SentryCurrentScopeStorage *)currentScopeStorage;

@end

@implementation SentryClientInternal (Attachments)

// The hint's attachments must be populated before prepareEvent runs the beforeSendWithHint
// callback, so the callback can add and remove attachments. After the callback returns, the
// hint's attachment list is authoritative and is what the SDK sends.
- (void)populateHintAttachments:(SentryHint *)hint
                          scope:(SentryScope *)scope
                   isFatalEvent:(BOOL)isFatalEvent
{
    NSMutableArray<SentryAttachment *> *allAttachments =
        [NSMutableArray arrayWithArray:scope.attachments];
    if (!isFatalEvent) {
        SentryScope *cs = [self.currentScopeStorage scope];
        if (cs != nil) {
            for (SentryAttachment *attachment in cs.attachments) {
                if ([allAttachments indexOfObjectIdenticalTo:attachment] == NSNotFound) {
                    [allAttachments addObject:attachment];
                }
            }
        }
    }
    [allAttachments addObjectsFromArray:hint.attachments];
    hint.attachments = allAttachments;
}

- (void)addAttachmentProcessor:(id<SentryClientAttachmentProcessor>)attachmentProcessor
{
    [self.attachmentProcessors addObject:attachmentProcessor];
}

- (void)removeAttachmentProcessor:(id<SentryClientAttachmentProcessor>)attachmentProcessor
{
    [self.attachmentProcessors removeObject:attachmentProcessor];
}

- (NSArray<SentryAttachment *> *)processAttachmentsForEvent:(SentryEvent *)event
                                                attachments:
                                                    (NSArray<SentryAttachment *> *)attachments
{
    if (self.attachmentProcessors.count == 0) {
        return attachments;
    }

    NSArray<SentryAttachment *> *processedAttachments = attachments;

    for (id<SentryClientAttachmentProcessor> attachmentProcessor in self.attachmentProcessors) {
        // Keep chaining the processed attachments so each processor works on the output of the
        // previous one. This is necessary so each processor can add and remove attachments.
        //
        // Important: This means the order of adding processors matters and relies on the
        // initialization order of the integrations. At this point in time the attachment processors
        // are only adding attachments, therefore we can ignore this restriction for now.
        processedAttachments = [attachmentProcessor processAttachments:processedAttachments
                                                              forEvent:event];
    }

    return processedAttachments;
}

@end

NS_ASSUME_NONNULL_END
