#import "SentryClient.h"
#import "SentryDataCategory.h"
#import "SentryDiscardReason.h"
#import <Foundation/Foundation.h>

@class SentryEnvelopeItem, SentryId, SentryAttachment, SentryThreadInspector;

NS_ASSUME_NONNULL_BEGIN

@protocol SentryClientAttachmentProcessor <NSObject>

- (nullable NSArray<SentryAttachment *> *)processAttachments:
                                              (nullable NSArray<SentryAttachment *> *)attachments
                                                    forEvent:(SentryEvent *)event;

@end

@interface
SentryClient (Private)

@property (nonatomic, weak) id<SentryClientAttachmentProcessor> attachmentProcessor;
@property (nonatomic, strong) SentryThreadInspector *threadInspector;

- (SentryFileManager *)fileManager;

- (SentryId *)captureError:(NSError *)error
               withSession:(SentrySession *)session
                 withScope:(SentryScope *)scope;

- (SentryId *)captureException:(NSException *)exception
                   withSession:(SentrySession *)session
                     withScope:(SentryScope *)scope;

- (SentryId *)captureCrashEvent:(SentryEvent *)event withScope:(SentryScope *)scope;

- (SentryId *)captureCrashEvent:(SentryEvent *)event
                    withSession:(SentrySession *)session
                      withScope:(SentryScope *)scope;

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));

/**
 * Needed by hybrid SDKs as react-native to synchronously store an envelope to disk.
 */
- (void)storeEnvelope:(SentryEnvelope *)envelope;

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason;

@end

NS_ASSUME_NONNULL_END
