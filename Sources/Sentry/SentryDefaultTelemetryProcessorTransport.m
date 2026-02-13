#import "SentryDefaultTelemetryProcessorTransport.h"
#import "SentrySwift.h"
#import "SentryTransportAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryDefaultTelemetryProcessorTransport ()

@property (nonatomic, strong) SentryTransportAdapter *transportAdapter;

@end

@implementation SentryDefaultTelemetryProcessorTransport

- (instancetype)initWithTransportAdapter:(SentryTransportAdapter *)transportAdapter
{
    if (self = [super init]) {
        self.transportAdapter = transportAdapter;
    }

    return self;
}

#pragma mark - SentryTelemetryProcessorTransport

- (void)sendEnvelopeWithEnvelope:(SentryEnvelope *)envelope
{
    [self.transportAdapter sendEnvelope:envelope];
}

@end

NS_ASSUME_NONNULL_END
