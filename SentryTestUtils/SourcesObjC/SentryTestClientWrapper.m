#import "SentryTestClientWrapper.h"

#import "SentryClient+Private.h"
#import "SentryEvent.h"
#import "SentrySwift.h"

@interface SentryClientInternal (SentryTestClientWrapperInitializer)

- (instancetype)initWithOptions:(NSObject *)options
                   dateProvider:(id<SentryCurrentDateProvider>)dateProvider
               transportAdapter:(SentryTransportAdapter *)transportAdapter
                    fileManager:(SentryFileManager *)fileManager
                threadInspector:(SentryDefaultThreadInspector *)threadInspector
             debugImageProvider:(SentryDebugImageProvider *)debugImageProvider
                         random:(id<SentryRandomProtocol>)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone
           eventContextEnricher:(id<SentryEventContextEnricher>)eventContextEnricher
               binaryImageCache:(SentryBinaryImageCache *)binaryImageCache
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

@end

@implementation SentryTestClientWrapper

- (instancetype)initWithOptions:(NSObject *)options
                   dateProvider:(id)dateProvider
               transportAdapter:(id)transportAdapter
                    fileManager:(id)fileManager
                threadInspector:(id)threadInspector
             debugImageProvider:(id)debugImageProvider
                         random:(id)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone
           eventContextEnricher:(id)eventContextEnricher
               binaryImageCache:(id)binaryImageCache
           dispatchQueueWrapper:(id)dispatchQueueWrapper
{
    return [super initWithOptions:options
                     dateProvider:dateProvider
                 transportAdapter:transportAdapter
                      fileManager:fileManager
                  threadInspector:threadInspector
               debugImageProvider:debugImageProvider
                           random:random
                           locale:locale
                         timezone:timezone
             eventContextEnricher:eventContextEnricher
                 binaryImageCache:binaryImageCache
             dispatchQueueWrapper:dispatchQueueWrapper];
}

- (void)captureSession:(SentrySession *)session
{
    [self wrapper_captureSession:session];
}

- (void)wrapper_captureSession:(id)session
{
}

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    return [self wrapper_captureEvent:event
                            withScope:scope
              additionalEnvelopeItems:additionalEnvelopeItems];
}

- (SentryId *)wrapper_captureEvent:(SentryEvent *)event
                         withScope:(SentryScope *)scope
           additionalEnvelopeItems:(NSArray *)additionalEnvelopeItems
{
    return event.eventId;
}

- (SentryId *)captureFatalEvent:(SentryEvent *)event
                    withSession:(SentrySession *)session
                      withScope:(SentryScope *)scope
{
    return [self wrapper_captureFatalEvent:event withSession:session withScope:scope];
}

- (SentryId *)wrapper_captureFatalEvent:(SentryEvent *)event
                            withSession:(id)session
                              withScope:(SentryScope *)scope
{
    return event.eventId;
}

- (void)captureFeedback:(SentryFeedback *)feedback withScope:(SentryScope *)scope
{
    [self wrapper_captureFeedback:feedback withScope:scope];
}

- (void)wrapper_captureFeedback:(id)feedback withScope:(SentryScope *)scope
{
}

- (void)captureEnvelope:(SentryEnvelope *)envelope
{
    [self wrapper_captureEnvelope:envelope];
}

- (void)wrapper_captureEnvelope:(id)envelope
{
}

- (void)storeEnvelope:(SentryEnvelope *)envelope
{
    [self wrapper_storeEnvelope:envelope];
}

- (void)wrapper_storeEnvelope:(id)envelope
{
}

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason
{
    [self wrapper_recordLostEvent:category reason:reason];
}

- (void)wrapper_recordLostEvent:(NSUInteger)category reason:(NSUInteger)reason
{
}

- (void)recordLostEvent:(SentryDataCategory)category
                 reason:(SentryDiscardReason)reason
               quantity:(NSUInteger)quantity
{
    [self wrapper_recordLostEvent:category reason:reason quantity:quantity];
}

- (void)wrapper_recordLostEvent:(NSUInteger)category
                         reason:(NSUInteger)reason
                       quantity:(NSUInteger)quantity
{
}

@end
