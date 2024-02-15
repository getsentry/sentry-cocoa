#import "SentrySpotlightTransport.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryEnvelopeItemType.h"
#import "SentryNSURLRequest.h"
#import "SentryNSURLRequestBuilder.h"
#import "SentryOptions.h"
#import "SentrySerialization.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySpotlightTransport ()

@property (nonatomic, strong) id<SentryRequestManager> requestManager;
@property (nonatomic, strong) SentryNSURLRequestBuilder *requestBuilder;
@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;

@end

@implementation SentrySpotlightTransport

- (id)initWithOptions:(SentryOptions *)options
          requestManager:(id<SentryRequestManager>)requestManager
          requestBuilder:(SentryNSURLRequestBuilder *)requestBuilder
    dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{

    if (self = [super init]) {
        self.options = options;
        self.requestManager = requestManager;
        self.requestBuilder = requestBuilder;
        self.dispatchQueue = dispatchQueueWrapper;
    }

    return self;
}

- (void)sendEnvelope:(SentryEnvelope *)envelope
{

    NSMutableArray<SentryEnvelopeItem *> *envelopeItems = [NSMutableArray new];
    for (SentryEnvelopeItem *item in envelope.items) {
        if ([item.header.type isEqualToString:SentryEnvelopeItemTypeEvent]) {
            [envelopeItems addObject:item];
        }
        if ([item.header.type isEqualToString:SentryEnvelopeItemTypeTransaction]) {
            [envelopeItems addObject:item];
        }
    }

    SentryEnvelope *envelopeWithoutAttachments =
        [[SentryEnvelope alloc] initWithHeader:envelope.header items:envelopeItems];

    [self.dispatchQueue dispatchAsyncWithBlock:^{
        NSURL *apiURL = [[NSURL alloc] initWithString:@"http://localhost:8969/stream"];

        NSURLRequest *request =
            [self.requestBuilder createEnvelopeRequest:envelopeWithoutAttachments
                                                   url:apiURL
                                      didFailWithError:nil];

        [self.requestManager
                   addRequest:request
            completionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {

            }];
    }];
}

- (SentryFlushResult)flush:(NSTimeInterval)timeout
{
    // Empty on purpose
    return kSentryFlushResultSuccess;
}

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason
{
    // Empty on purpose
}

@end

NS_ASSUME_NONNULL_END
