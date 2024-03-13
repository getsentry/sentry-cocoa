#import "SentryEnvelope.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryClientReport;

@interface
SentryEnvelopeItem ()

- (instancetype)initWithClientReport:(SentryClientReport *)clientReport;

@end

NS_ASSUME_NONNULL_END
